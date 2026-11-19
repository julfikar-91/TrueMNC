// functions/src/__tests__/seedData.test.ts
import { describe, it } from "node:test";
import * as assert from "node:assert/strict";
import { CATEGORIES_SEED } from "../../scripts/seedCategories";
import { SCORING_CONFIG_V1, APP_CONFIG } from "../../scripts/seedConfig";
import { INITIAL_GLOBAL_STATS } from "../../scripts/seedStats";

describe("Seed Scripts Data Integrity Tests", () => {
  describe("Categories Seed Validation", () => {
    it("contains exactly 20 categories (10 Technical + 10 Non-Technical)", () => {
      assert.equal(CATEGORIES_SEED.length, 20);

      const technical = CATEGORIES_SEED.filter((c) => c.type === "TECHNICAL");
      const nonTechnical = CATEGORIES_SEED.filter((c) => c.type === "NON_TECHNICAL");

      assert.equal(technical.length, 10);
      assert.equal(nonTechnical.length, 10);
    });

    it("verifies all required Technical categories exist with order 1-10", () => {
      const expectedTechNames = [
        "Software Development",
        "Data Science",
        "AI/ML",
        "Cyber Security",
        "Cloud",
        "DevOps",
        "Testing",
        "UI/UX",
        "Database",
        "Networking",
      ];

      for (let i = 0; i < expectedTechNames.length; i++) {
        const cat = CATEGORIES_SEED[i];
        assert.equal(cat.name, expectedTechNames[i]);
        assert.equal(cat.type, "TECHNICAL");
        assert.equal(cat.order, i + 1);
        assert.equal(cat.active, true);
        assert.equal(cat.activeCount, 0);
        assert.ok(cat.aliases.length > 0, `${cat.name} must have aliases`);
        assert.ok(cat.keywords.length > 0, `${cat.name} must have keywords`);
      }
    });

    it("verifies all required Non-Technical categories exist with order 11-20", () => {
      const expectedNonTechNames = [
        "HR",
        "Finance",
        "Marketing",
        "Sales",
        "Business Development",
        "Operations",
        "Administration",
        "Customer Support",
        "Business Analysis",
        "Management",
      ];

      for (let i = 0; i < expectedNonTechNames.length; i++) {
        const cat = CATEGORIES_SEED[i + 10];
        assert.equal(cat.name, expectedNonTechNames[i]);
        assert.equal(cat.type, "NON_TECHNICAL");
        assert.equal(cat.order, i + 11);
        assert.equal(cat.active, true);
        assert.equal(cat.activeCount, 0);
        assert.ok(cat.aliases.length > 0, `${cat.name} must have aliases`);
        assert.ok(cat.keywords.length > 0, `${cat.name} must have keywords`);
      }
    });
  });

  describe("Config Seed Validation", () => {
    it("validates scoring_v1 config weights total 100 with required thresholds", () => {
      const { weights, threshold, softCapCoverage, softCap, labelCutoffs } = SCORING_CONFIG_V1;

      assert.equal(weights.skills, 40);
      assert.equal(weights.education, 15);
      assert.equal(weights.experience, 15);
      assert.equal(weights.location, 10);
      assert.equal(weights.preference, 20);

      const totalWeight =
        weights.skills +
        weights.education +
        weights.experience +
        weights.location +
        weights.preference;
      assert.equal(totalWeight, 100);

      assert.equal(threshold, 55);
      assert.equal(softCapCoverage, 0.5);
      assert.equal(softCap, 74);
      assert.equal(labelCutoffs.excellent, 80);
      assert.equal(labelCutoffs.good, 65);
      assert.equal(labelCutoffs.fair, 55);
    });

    it("validates app config settings, notifications, and AI model names", () => {
      assert.equal(APP_CONFIG.minAppVersion, "1.0.0");
      assert.equal(APP_CONFIG.notifications.maxPushesPerDay, 3);
      assert.equal(APP_CONFIG.notifications.quietHours.start, "22:00");
      assert.equal(APP_CONFIG.notifications.quietHours.end, "08:00");

      assert.ok(APP_CONFIG.aiModels.geminiMatchModel.length > 0);
      assert.ok(APP_CONFIG.aiModels.geminiSummaryModel.length > 0);
      assert.ok(APP_CONFIG.aiModels.geminiParserModel.length > 0);
    });
  });

  describe("Stats Seed Validation", () => {
    it("contains initial zero counters for all JobStatus values, companies, and sources", () => {
      const allJobStatuses = [
        "DRAFT_RAW",
        "PENDING_REVIEW",
        "ACTIVE",
        "CLOSING_SOON",
        "EXPIRED",
        "CLOSED",
        "REJECTED",
        "DUPLICATE",
      ];

      for (const status of allJobStatuses) {
        assert.equal(
          (INITIAL_GLOBAL_STATS as unknown as Record<string, number>)[status],
          0,
          `Status counter for ${status} must be 0`,
        );
        assert.equal(
          INITIAL_GLOBAL_STATS.jobCountsByStatus[
            status as keyof typeof INITIAL_GLOBAL_STATS.jobCountsByStatus
          ],
          0,
          `Nested status counter for ${status} must be 0`,
        );
      }

      assert.equal(INITIAL_GLOBAL_STATS.companies, 0);
      assert.equal(INITIAL_GLOBAL_STATS.sources, 0);
      assert.equal(INITIAL_GLOBAL_STATS.totalJobs, 0);
      assert.equal(INITIAL_GLOBAL_STATS.users, 0);
      assert.equal(INITIAL_GLOBAL_STATS.reports, 0);
    });
  });
});
