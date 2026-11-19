// functions/src/__tests__/verificationRules.test.ts
import { describe, it } from "node:test";
import * as assert from "node:assert";

import {
  ruleR1SourceApproved,
  ruleR2Domain,
  ruleR4RequiredFields,
  ruleR5Freshness,
  ruleR6Duplicate,
  ruleR7AiConfidence,
  ruleR8Safety,
  runRules,
  computeDedupeKey,
  isAuthoritativeDomainMatch,
} from "../rules/verificationRules";

describe("Rule Verification Engine (R1 - R8)", () => {
  // ── R1: Source Approved ────────────────────────────────────────────────────
  describe("R1: Source Approved", () => {
    it("PASSES when source is enabled and company is verified", () => {
      const res = ruleR1SourceApproved(
        { enabled: true },
        { sourceVerified: true },
      );
      assert.strictEqual(res.result, "PASS");
    });

    it("FAILS when source is disabled", () => {
      const res = ruleR1SourceApproved(
        { enabled: false },
        { sourceVerified: true },
      );
      assert.strictEqual(res.result, "FAIL");
    });

    it("FAILS when company is unverified", () => {
      const res = ruleR1SourceApproved(
        { enabled: true },
        { sourceVerified: false },
      );
      assert.strictEqual(res.result, "FAIL");
    });
  });

  // ── R2: Domain & Lookalike Rejection ───────────────────────────────────────
  describe("R2: Domain & Anti-Lookalike Enforcement", () => {
    const companyDomain = "acmecorp.com";

    const tableCases: Array<{
      url: string;
      expected: "PASS" | "FAIL";
      reason: string;
    }> = [
      {
        url: "https://acmecorp.com/jobs/123",
        expected: "PASS",
        reason: "Exact company domain",
      },
      {
        url: "https://careers.acmecorp.com/apply/456",
        expected: "PASS",
        reason: "Legitimate subdomain",
      },
      {
        url: "https://jobs.tech.acmecorp.com/post/789",
        expected: "PASS",
        reason: "Nested subdomain",
      },
      {
        url: "https://boards.greenhouse.io/acmecorp/jobs/101",
        expected: "PASS",
        reason: "Standard approved ATS host (Greenhouse)",
      },
      {
        url: "https://jobs.lever.co/acmecorp/202",
        expected: "PASS",
        reason: "Standard approved ATS host (Lever)",
      },
      // LOOKALIKE ATTACKS THAT MUST FAIL:
      {
        url: "https://acmecorp.com.evil.com/jobs/123",
        expected: "FAIL",
        reason: "Suffix lookalike attack (ends with evil.com)",
      },
      {
        url: "https://evilacmecorp.com/jobs/123",
        expected: "FAIL",
        reason: "Prefix lookalike attack",
      },
      {
        url: "https://evil-acmecorp.com/jobs/123",
        expected: "FAIL",
        reason: "Hyphenated prefix attack",
      },
      {
        url: "https://acmecorp-careers.com/jobs/123",
        expected: "FAIL",
        reason: "Lookalike variant",
      },
      {
        url: "https://phishing.com/apply?company=acmecorp.com",
        expected: "FAIL",
        reason: "Query parameter spoofing",
      },
    ];

    for (const tc of tableCases) {
      it(`${tc.expected}: ${tc.reason} (${tc.url})`, () => {
        const res = ruleR2Domain(tc.url, companyDomain);
        assert.strictEqual(
          res.result,
          tc.expected,
          `Failed for ${tc.url}: ${res.details}`,
        );
      });
    }

    it("helper isAuthoritativeDomainMatch accurately blocks lookalikes", () => {
      assert.strictEqual(
        isAuthoritativeDomainMatch("acmecorp.com.evil.com", "acmecorp.com"),
        false,
      );
      assert.strictEqual(
        isAuthoritativeDomainMatch("evilsite.com", "acmecorp.com"),
        false,
      );
      assert.strictEqual(
        isAuthoritativeDomainMatch("jobs.acmecorp.com", "acmecorp.com"),
        true,
      );
    });
  });

  // ── R4: Required Fields ────────────────────────────────────────────────────
  describe("R4: Required Fields", () => {
    const validJob = {
      title: "Senior Backend Engineer",
      companyName: "Acme Corp",
      location: "Bengaluru, Karnataka",
      remote: false,
      description:
        "We are looking for a Senior Backend Engineer with extensive TypeScript and distributed systems experience to build high-scale cloud platforms.",
    };

    it("PASSES when all mandatory fields are present and valid", () => {
      const res = ruleR4RequiredFields(validJob);
      assert.strictEqual(res.result, "PASS");
    });

    it("PASSES when location is null but remote is true", () => {
      const res = ruleR4RequiredFields({
        ...validJob,
        location: null,
        remote: true,
      });
      assert.strictEqual(res.result, "PASS");
    });

    it("FAILS when title is empty", () => {
      const res = ruleR4RequiredFields({
        ...validJob,
        title: "",
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /title/);
    });

    it("FAILS when description is under 80 characters", () => {
      const res = ruleR4RequiredFields({
        ...validJob,
        description: "Too short job description.",
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /80 characters/);
    });

    it("FAILS when location is missing and remote is false", () => {
      const res = ruleR4RequiredFields({
        ...validJob,
        location: null,
        remote: false,
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /location or remote flag/);
    });
  });

  // ── R5: Freshness ──────────────────────────────────────────────────────────
  describe("R5: Freshness & Expiration", () => {
    it("PASSES when postedAt is present and deadline is in the future", () => {
      const res = ruleR5Freshness({
        postedAt: new Date(),
        deadline: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      });
      assert.strictEqual(res.result, "PASS");
    });

    it("FAILS when deadline is in the past (EXPIRED)", () => {
      const res = ruleR5Freshness({
        postedAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
        deadline: new Date(Date.now() - 24 * 60 * 60 * 1000), // yesterday
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /expired/i);
    });

    it("FAILS when both postedAt and firstSeenAt are missing", () => {
      const res = ruleR5Freshness({
        postedAt: null,
        firstSeenAt: null,
      });
      assert.strictEqual(res.result, "FAIL");
    });
  });

  // ── R6: Duplicate Detection ────────────────────────────────────────────────
  describe("R6: Duplicate Detection", () => {
    const key = computeDedupeKey({
      companyId: "comp_123",
      title: "Software Engineer",
      city: "Bengaluru",
      sourceJobId: "gh_5544",
    });

    it("PASSES when dedupe key is not in existing keys set", () => {
      const existing = new Set<string>(["other_key_1", "other_key_2"]);
      const res = ruleR6Duplicate(key, existing);
      assert.strictEqual(res.result, "PASS");
    });

    it("FAILS when dedupe key already exists in active jobs", () => {
      const existing = new Set<string>([key]);
      const res = ruleR6Duplicate(key, existing);
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /duplicate/i);
    });
  });

  // ── R7: AI Extraction Confidence ───────────────────────────────────────────
  describe("R7: AI Extraction Confidence", () => {
    it("PASSES when confidence >= 0.70 and schema is valid", () => {
      const res = ruleR7AiConfidence({
        confidence: 0.85,
        isValidSchema: true,
      });
      assert.strictEqual(res.result, "PASS");
    });

    it("FAILS when confidence is below 0.70", () => {
      const res = ruleR7AiConfidence({
        confidence: 0.65,
        isValidSchema: true,
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /threshold/);
    });

    it("FAILS when AI schema is invalid", () => {
      const res = ruleR7AiConfidence({
        confidence: 0.95,
        isValidSchema: false,
      });
      assert.strictEqual(res.result, "FAIL");
    });
  });

  // ── R8: Safety Checks ──────────────────────────────────────────────────────
  describe("R8: Safety Checks", () => {
    it("PASSES for legitimate, safe job descriptions", () => {
      const res = ruleR8Safety({
        applyUrl: "https://careers.acme.com/jobs/123",
        description:
          "Acme is looking for a DevOps Engineer. Competitive salary and benefits package included.",
      });
      assert.strictEqual(res.result, "PASS");
    });

    it("FAILS on payment request wording ('registration fee')", () => {
      const res = ruleR8Safety({
        applyUrl: "https://careers.acme.com/jobs/123",
        description:
          "Candidates must pay a refundable registration fee of 500 INR before the interview.",
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /registration fee/);
    });

    it("FAILS on personal data collection wording ('send bank details')", () => {
      const res = ruleR8Safety({
        applyUrl: "https://careers.acme.com/jobs/123",
        description:
          "Please send bank details and debit card copy along with your resume.",
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /bank details/);
    });

    it("FAILS on URL shortener in applyUrl ('bit.ly')", () => {
      const res = ruleR8Safety({
        applyUrl: "https://bit.ly/apply-fast-job",
        description: "Great developer job opening. Apply now.",
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /URL shortener/);
    });

    it("FAILS on IP-address URL in applyUrl or description", () => {
      const res = ruleR8Safety({
        applyUrl: "http://192.168.1.50:8080/apply",
        description: "Apply at our internal server.",
      });
      assert.strictEqual(res.result, "FAIL");
      assert.match(res.details!, /raw IP-address/);
    });
  });

  // ── Overall runRules Orchestrator ──────────────────────────────────────────
  describe("runRules() Orchestrator", () => {
    it("returns allPass = true when all rules succeed", async () => {
      const res = await runRules(
        {
          source: { enabled: true },
          company: {
            id: "comp_1",
            domain: "company.com",
            sourceVerified: true,
          },
          job: {
            title: "Software Engineer",
            companyId: "comp_1",
            companyName: "Acme",
            applyUrl: "https://company.com/jobs/123",
            description:
              "A very comprehensive job description with more than eighty characters to satisfy mandatory field checks.",
            location: "Mumbai",
            postedAt: new Date(),
          },
          aiExtraction: {
            confidence: 0.9,
            isValidSchema: true,
          },
        },
        { skipLiveProbe: true },
      );

      assert.strictEqual(res.allPass, true);
      assert.strictEqual(res.reasonCodes.length, 0);
    });

    it("collects appropriate reason codes when rules fail", async () => {
      const res = await runRules(
        {
          source: { enabled: false }, // R1 fail
          company: {
            id: "comp_1",
            domain: "company.com",
            sourceVerified: false,
          },
          job: {
            title: "", // R4 fail
            applyUrl: "https://evil.com/jobs/123", // R2 fail
            description: "Short", // R4 fail
          },
        },
        { skipLiveProbe: true },
      );

      assert.strictEqual(res.allPass, false);
      assert.ok(res.reasonCodes.includes("R1_FAIL"));
      assert.ok(res.reasonCodes.includes("R2_FAIL"));
      assert.ok(res.reasonCodes.includes("R4_FAIL"));
    });
  });
});
