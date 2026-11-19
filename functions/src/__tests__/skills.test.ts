// functions/src/__tests__/skills.test.ts
import { describe, it } from "node:test";
import * as assert from "node:assert/strict";
import { normaliseSkill, SKILLS_DICTIONARY } from "../matching/skills";

describe("Skills Taxonomy & normaliseSkill Unit Tests", () => {
  it("contains at least 150 canonical skills in the dictionary", () => {
    assert.ok(
      SKILLS_DICTIONARY.length >= 150,
      `Expected at least 150 skills, found ${SKILLS_DICTIONARY.length}`,
    );
  });

  it("ensures every skill entry has valid canonicalId, name, category, and relatedGroupId", () => {
    const validCategories = new Set([
      "language",
      "framework",
      "db",
      "cloud",
      "tool",
      "soft",
    ]);

    for (const skill of SKILLS_DICTIONARY) {
      assert.ok(skill.canonicalId.length > 0, "canonicalId must not be empty");
      assert.ok(skill.name.length > 0, "name must not be empty");
      assert.ok(
        validCategories.has(skill.category),
        `Invalid category ${skill.category} for ${skill.canonicalId}`,
      );
      assert.ok(skill.relatedGroupId.length > 0, "relatedGroupId must not be empty");
      assert.ok(Array.isArray(skill.aliases), "aliases must be an array");
    }
  });

  describe("Alias normalization", () => {
    it("normalizes common programming language aliases", () => {
      // JS aliases
      assert.deepEqual(normaliseSkill("JS"), {
        canonicalId: "javascript",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("javascript"), {
        canonicalId: "javascript",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("Java Script"), {
        canonicalId: "javascript",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("ecmascript"), {
        canonicalId: "javascript",
        flagged: false,
      });

      // TypeScript
      assert.deepEqual(normaliseSkill("TS"), {
        canonicalId: "typescript",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("type script"), {
        canonicalId: "typescript",
        flagged: false,
      });

      // Python
      assert.deepEqual(normaliseSkill("py"), {
        canonicalId: "python",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("python3"), {
        canonicalId: "python",
        flagged: false,
      });

      // Golang
      assert.deepEqual(normaliseSkill("golang"), {
        canonicalId: "go",
        flagged: false,
      });
    });

    it("normalizes database aliases into canonical IDs", () => {
      assert.deepEqual(normaliseSkill("postgres"), {
        canonicalId: "postgresql",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("psql"), {
        canonicalId: "postgresql",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("mongo"), {
        canonicalId: "mongodb",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("firestore"), {
        canonicalId: "cloud-firestore",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("big query"), {
        canonicalId: "bigquery",
        flagged: false,
      });
    });

    it("normalizes cloud and devops aliases", () => {
      assert.deepEqual(normaliseSkill("k8s"), {
        canonicalId: "kubernetes",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("amazon web services"), {
        canonicalId: "aws",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("google cloud"), {
        canonicalId: "gcp",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("cicd"), {
        canonicalId: "ci-cd",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("gha"), {
        canonicalId: "github-actions",
        flagged: false,
      });
    });

    it("normalizes frameworks & mobile platforms", () => {
      assert.deepEqual(normaliseSkill("rn"), {
        canonicalId: "react-native",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("react native"), {
        canonicalId: "react-native",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("next.js"), {
        canonicalId: "nextjs",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("flutter framework"), {
        canonicalId: "flutter",
        flagged: false,
      });
    });
  });

  describe("Case insensitivity and spacing resilience", () => {
    it("handles uppercase, mixed case, and punctuation variations", () => {
      assert.deepEqual(normaliseSkill("JAVASCRIPT"), {
        canonicalId: "javascript",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("FlUtTeR"), {
        canonicalId: "flutter",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("Node.JS"), {
        canonicalId: "nodejs",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("C++"), {
        canonicalId: "cpp",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("C#"), {
        canonicalId: "csharp",
        flagged: false,
      });
    });

    it("normalizes multiple irregular spaces, tabs, and leading/trailing whitespace", () => {
      assert.deepEqual(normaliseSkill("   Java    Script   "), {
        canonicalId: "javascript",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("\tType   Script\n"), {
        canonicalId: "typescript",
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("  Spring   Boot  "), {
        canonicalId: "spring-boot",
        flagged: false,
      });
    });
  });

  describe("Unknown skills handling and flagging", () => {
    it("flags unknown or unrecognized skills for manual admin review", () => {
      assert.deepEqual(normaliseSkill("FakeNonExistentTool2026"), {
        canonicalId: null,
        flagged: true,
      });
      assert.deepEqual(normaliseSkill("CustomProprietaryFrameworkX"), {
        canonicalId: null,
        flagged: true,
      });
      assert.deepEqual(normaliseSkill("Abc123SkillXYZ"), {
        canonicalId: null,
        flagged: true,
      });
    });

    it("handles empty and null inputs safely without flagging", () => {
      assert.deepEqual(normaliseSkill(""), {
        canonicalId: null,
        flagged: false,
      });
      assert.deepEqual(normaliseSkill("   "), {
        canonicalId: null,
        flagged: false,
      });
      assert.deepEqual(normaliseSkill(null), {
        canonicalId: null,
        flagged: false,
      });
      assert.deepEqual(normaliseSkill(undefined), {
        canonicalId: null,
        flagged: false,
      });
    });
  });
});
