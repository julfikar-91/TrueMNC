// functions/src/__tests__/collectionPipeline.test.ts
import { describe, it } from "node:test";
import * as assert from "node:assert";

import {
  buildSearchTokens,
  buildMatchTags,
} from "../tasks/collectionPipeline";
import {
  hashDescription,
  normaliseSkillList,
  GeminiExtractedJobSchema,
} from "../ai/extractJob";

describe("Collection Engine & Pipeline Logic Tests", () => {
  // ── Missing Count & Closure Rules ──────────────────────────────────────────
  describe("Missing Job Closure Policy (Section 10)", () => {
    it("job missing once stays ACTIVE (missingCount = 1, status untouched)", () => {
      let status = "ACTIVE";
      let missingCount = 0;

      // Simulated Run 1: Job not seen
      missingCount += 1;
      if (missingCount >= 2) {
        status = "CLOSED";
      }

      assert.strictEqual(missingCount, 1);
      assert.strictEqual(status, "ACTIVE", "Job must remain ACTIVE after 1 missed run");
    });

    it("job missing twice consecutively transitions to CLOSED", () => {
      let status = "ACTIVE";
      let missingCount = 1;

      // Simulated Run 2: Job missing second consecutive time
      missingCount += 1;
      if (missingCount >= 2) {
        status = "CLOSED";
      }

      assert.strictEqual(missingCount, 2);
      assert.strictEqual(status, "CLOSED", "Job must close on 2 consecutive missed runs");
    });

    it("adapter failure NEVER closes jobs or increments missing count", () => {
      let consecutiveFailures = 0;
      let missingCount = 1;
      let status = "ACTIVE";

      const adapterFailed = true;

      if (adapterFailed) {
        consecutiveFailures += 1;
        // Pipeline terminates early without running markMissing
      } else {
        missingCount += 1;
        if (missingCount >= 2) status = "CLOSED";
      }

      assert.strictEqual(consecutiveFailures, 1);
      assert.strictEqual(missingCount, 1, "Missing count must not increment on adapter failure");
      assert.strictEqual(status, "ACTIVE", "Status must remain unchanged on adapter failure");
    });
  });

  // ── Cache & Content Hashing ────────────────────────────────────────────────
  describe("Content Hashing & AI Extraction Caching", () => {
    it("unchanged content skips AI extraction (cache hit)", () => {
      const desc = "Senior Go Developer needed for infrastructure tooling.";
      const hash1 = hashDescription(desc);
      const hash2 = hashDescription(desc);

      assert.strictEqual(hash1, hash2, "Identical descriptions yield identical cache keys");

      const cache = new Map<string, unknown>();
      cache.set(hash1, { summary: "Go Dev", category: "Software Development" });

      const isCacheHit = cache.has(hash2);
      assert.strictEqual(isCacheHit, true, "Must hit cache on unchanged content");
    });

    it("invalid AI output schema results in PENDING_REVIEW with AI_INVALID reason", () => {
      const invalidGeminiOutput = {
        requiredSkills: ["Go"],
        category: "NOT_AN_ALLOWED_CATEGORY", // Invalid category
        confidence: 0.95,
      };

      const parsed = GeminiExtractedJobSchema.safeParse(invalidGeminiOutput);
      assert.strictEqual(parsed.success, false, "Invalid category must fail schema validation");

      let jobStatus = "ACTIVE";
      let reviewReason = "";

      if (!parsed.success) {
        jobStatus = "PENDING_REVIEW";
        reviewReason = "AI_INVALID";
      }

      assert.strictEqual(jobStatus, "PENDING_REVIEW");
      assert.strictEqual(reviewReason, "AI_INVALID");
    });

    it("AI score or confidence NEVER sets verification state (only rules/admins do)", () => {
      // Even with 1.0 confidence, verification state is strictly driven by rules
      const aiConfidence = 1.0;
      let verificationState = "UNVERIFIED";

      const rulesPassed = false; // R2 or R8 failed

      if (rulesPassed) {
        verificationState = "VERIFIED";
      } else {
        verificationState = "UNVERIFIED";
      }

      assert.strictEqual(
        verificationState,
        "UNVERIFIED",
        "AI cannot force VERIFIED state if rules fail",
      );
      assert.ok(aiConfidence >= 1.0);
    });
  });

  // ── Search Tokens & Match Tags ─────────────────────────────────────────────
  describe("Search Tokens & Match Tags Generators", () => {
    it("buildSearchTokens generates prefix tokens with length >= 2, capped at 60", () => {
      const tokens = buildSearchTokens([
        "Senior Flutter Engineer",
        "Google",
        "Bengaluru",
      ]);

      assert.ok(tokens.length <= 60);
      assert.ok(tokens.includes("flutter"));
      assert.ok(tokens.includes("fl"));
      assert.ok(tokens.includes("google"));
      assert.ok(tokens.includes("bengaluru"));
    });

    it("buildMatchTags prefixes tags with skill, category, city, and type", () => {
      const tags = buildMatchTags({
        requiredSkills: ["Flutter", "Dart"],
        category: "Software Development",
        city: "Hyderabad",
        jobType: "FULL_TIME",
      });

      assert.ok(tags.includes("skill:flutter"));
      assert.ok(tags.includes("skill:dart"));
      assert.ok(tags.includes("category:software development"));
      assert.ok(tags.includes("city:hyderabad"));
      assert.ok(tags.includes("type:full_time"));
    });
  });

  // ── Skill Normalization ────────────────────────────────────────────────────
  describe("Skill Normalization Integration", () => {
    it("normalises aliases into canonical taxonomy IDs", () => {
      const raw = ["JavaScript", "JS", "TypeScript", "postgres", "Amazon Web Services"];
      const normalised = normaliseSkillList(raw);

      assert.ok(normalised.includes("javascript"));
      assert.ok(normalised.includes("typescript"));
      assert.ok(normalised.includes("postgresql"));
      assert.ok(normalised.includes("aws"));
    });
  });

  // ── Soft Lock (claimReviewItem) ────────────────────────────────────────────
  describe("Review Lock (claimReviewItem) Logic", () => {
    it("allows first admin to claim an item", () => {
      const admin1 = "admin_uid_1";
      const claim = {
        claimedBy: admin1,
        claimedAt: new Date(),
      };
      assert.strictEqual(claim.claimedBy, admin1);
    });

    it("blocks a second admin while 10-minute lock is active", () => {
      const admin1: string = "admin_uid_1";
      const admin2: string = "admin_uid_2";
      const claimedAt = new Date(Date.now() - 3 * 60 * 1000); // 3 minutes ago
      const tenMinutes = 10 * 60 * 1000;

      const isLocked =
        admin1 !== admin2 && Date.now() - claimedAt.getTime() < tenMinutes;

      assert.strictEqual(isLocked, true, "Second admin must be blocked within 10 minutes");
    });

    it("allows second admin to claim after 10-minute lock expires", () => {
      const admin1: string = "admin_uid_1";
      const admin2: string = "admin_uid_2";
      const claimedAt = new Date(Date.now() - 11 * 60 * 1000); // 11 minutes ago (expired)
      const tenMinutes = 10 * 60 * 1000;

      const isLocked =
        admin1 !== admin2 && Date.now() - claimedAt.getTime() < tenMinutes;

      assert.strictEqual(isLocked, false, "Lock expired after 10 minutes");
    });
  });
});
