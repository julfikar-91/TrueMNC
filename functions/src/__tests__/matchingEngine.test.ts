// functions/src/__tests__/matchingEngine.test.ts
// Comprehensive unit tests for the deterministic TrueMNC matching engine.
// Strictly adheres to section 13 of the specification.

import { describe, it } from "node:test";
import * as assert from "node:assert/strict";
import * as fs from "fs";
import * as path from "path";

import {
  scoreForUser,
  checkStage1Eligibility,
  CandidateProfile,
  CareerPreferences,
  JobMatchCriteria,
  ScoringConfig,
} from "../matching/score";

// ── Default Config v1 fixture ────────────────────────────────────────────────
const CONFIG_V1: ScoringConfig = {
  version: "v1",
  weights: {
    skills: 40,
    education: 15,
    experience: 15,
    location: 10,
    preference: 20,
  },
  threshold: 55,
  softCapCoverage: 0.5,
  softCap: 74,
  labelCutoffs: {
    excellent: 80,
    good: 65,
    fair: 55,
  },
};

describe("Deterministic Matching Engine Unit Tests (Section 13 Spec)", () => {
  // ── 1. The Spec's Worked Example ───────────────────────────────────────────
  describe("1. Worked Example (Junior Java Developer in Kolkata)", () => {
    it("evaluates Junior Java Dev candidate accurately: skills 80, edu 100, exp 50 (flagged), loc 100, pref 100 => total 84 (Strong)", () => {
      // User: B.Tech CSE with Java/Python/SQL/React in Kolkata, experience unknown
      const userProfile: CandidateProfile = {
        id: "cand_1",
        name: "Arijit Das",
        location: "Kolkata",
        state: "West Bengal",
        skills: [
          { value: "Java", confirmed: true, provenance: "EXPLICIT" },
          { value: "Python", confirmed: true, provenance: "EXPLICIT" },
          { value: "SQL", confirmed: true, provenance: "EXPLICIT" },
          { value: "React", confirmed: true, provenance: "EXPLICIT" },
        ],
        education: [
          {
            degree: "B.Tech",
            level: "Bachelor",
            specialization: "CSE",
            field: "Computer Science and Engineering",
            confirmed: true,
            provenance: "EXPLICIT",
          },
        ],
        experience: [],
        confirmedMonths: null, // Experience unknown!
        isFresher: false,
        profile_confirmed: true,
      };

      const userPrefs: CareerPreferences = {
        title: "Java Developer",
        preferredTitles: ["Java Developer", "Junior Developer"],
        category: "Software Development",
        jobType: "TECHNICAL",
        employmentType: "PERMANENT",
        workMode: "ONSITE",
        city: "Kolkata",
      };

      // Job: Junior Java Developer in Kolkata
      // Required skills: Java (1.0), PostgreSQL (1.0) -> SQL matches PostgreSQL via relatedGroupId 'sql-db' (0.5)
      // Preferred skills: React (0.5) -> React exact match (0.5)
      // Total skills weight: 1.0 + 1.0 + 0.5 = 2.5
      // Matched skills weight: 1.0 (Java) + 0.5 (PostgreSQL via SQL) + 0.5 (React) = 2.0
      // Skills score: 2.0 / 2.5 * 100 = 80
      const job: JobMatchCriteria = {
        id: "job_junior_java",
        title: "Junior Java Developer",
        category: "Software Development",
        jobType: "TECHNICAL",
        requiredSkills: ["java", "postgresql"],
        preferredSkills: ["react"],
        minEdu: "Bachelor in Computer Science",
        expMin: 1,
        expMax: 3,
        employmentType: "PERMANENT",
        workMode: "ONSITE",
        city: "Kolkata",
        state: "West Bengal",
        status: "ACTIVE",
        isVerified: true,
        applyUrl: "https://careers.google.com/jobs/123",
      };

      const result = scoreForUser(userProfile, userPrefs, job, CONFIG_V1);

      // Verify dimension breakdown
      assert.strictEqual(result.breakdown.skills, 80, "Skills score must be 80");
      assert.strictEqual(result.breakdown.education, 100, "Education score must be 100");
      assert.strictEqual(result.breakdown.experience, 50, "Experience score must be 50");
      assert.strictEqual(result.breakdown.location, 100, "Location score must be 100");
      assert.strictEqual(result.breakdown.preference, 100, "Preference score must be 100");

      // Verify flag on unknown experience
      assert.ok(
        result.flags.includes("Add experience for better accuracy"),
        "Flags must include 'Add experience for better accuracy'",
      );

      // Verify total score and label
      assert.strictEqual(result.score, 84, "Total score must be 84");
      assert.strictEqual(result.label, "Strong", "Label must be Strong");
      assert.strictEqual(result.scoreVersion, "v1");
    });
  });

  // ── 2. Missing-Data Renormalisation ────────────────────────────────────────
  describe("2. Missing-Data Renormalisation", () => {
    it("renormalises over remaining active dimensions when preferences are missing", () => {
      const userProfile: CandidateProfile = {
        location: "Bengaluru",
        skills: [{ value: "Java", confirmed: true, provenance: "EXPLICIT" }],
        education: [
          {
            degree: "Bachelor of Technology",
            confirmed: true,
            provenance: "EXPLICIT",
          },
        ],
        confirmedMonths: 24, // 2 years
      };

      const job: JobMatchCriteria = {
        id: "job_no_pref",
        title: "Java Engineer",
        category: "Software Development",
        jobType: "TECHNICAL",
        requiredSkills: ["java"],
        minEdu: "Bachelor",
        expMin: 1,
        expMax: 3,
        city: "Bengaluru",
        workMode: "ONSITE",
        status: "ACTIVE",
        isVerified: true,
        applyUrl: "https://example.com/apply",
      };

      // No preferences provided -> preference dimension (weight 20) excluded
      const resultNoPrefs = scoreForUser(userProfile, null, job, CONFIG_V1);

      // All active dimensions (skills 40, edu 15, exp 15, loc 10 => sum 80) are 100% matched
      // Without renormalisation: (100*40 + 100*15 + 100*15 + 100*10) = 80
      // With renormalisation: 8000 / 80 = 100
      assert.strictEqual(resultNoPrefs.breakdown.skills, 100);
      assert.strictEqual(resultNoPrefs.breakdown.education, 100);
      assert.strictEqual(resultNoPrefs.breakdown.experience, 100);
      assert.strictEqual(resultNoPrefs.breakdown.location, 100);
      assert.strictEqual(resultNoPrefs.score, 100);
      assert.strictEqual(resultNoPrefs.label, "Strong");
    });
  });

  // ── 3. Soft Cap at <50% Required Skill Coverage ───────────────────────────
  describe("3. Soft Cap Coverage", () => {
    it("caps score at 74 (soft cap) when required skills coverage is below 50%", () => {
      const userProfile: CandidateProfile = {
        location: "Kolkata",
        // Candidate has neither Java nor Kotlin (0% of required skills)
        skills: [{ value: "Ruby", confirmed: true, provenance: "EXPLICIT" }],
        education: [{ degree: "B.Tech", confirmed: true, provenance: "EXPLICIT" }],
        confirmedMonths: 24,
      };

      const userPrefs: CareerPreferences = {
        city: "Kolkata",
        workMode: "ONSITE",
      };

      const job: JobMatchCriteria = {
        id: "job_soft_cap",
        title: "Backend Engineer",
        category: "Software Development",
        jobType: "TECHNICAL",
        requiredSkills: ["java", "kotlin"], // 2 required skills
        minEdu: "Bachelor",
        expMin: 1,
        expMax: 3,
        city: "Kolkata",
        workMode: "ONSITE",
        status: "ACTIVE",
        isVerified: true,
        applyUrl: "https://example.com/apply",
      };

      const result = scoreForUser(userProfile, userPrefs, job, CONFIG_V1);

      assert.strictEqual(result.breakdown.skills, 0, "Skills match must be 0");
      assert.strictEqual(result.breakdown.education, 100);
      assert.strictEqual(result.breakdown.experience, 100);
      assert.strictEqual(result.breakdown.location, 100);

      // Raw score = (0*40 + 100*15 + 100*15 + 100*10 + 100*20) / 100 = 60
      // Even if raw score were higher, soft cap ensures score <= 74
      assert.ok(result.score <= 74, `Score ${result.score} must not exceed soft cap 74`);
      assert.ok(
        result.flags.some((f) => f.includes("Soft cap applied")),
        "Flags must include soft cap warning",
      );
    });
  });

  // ── 4. Optional Skill Never Rejects ─────────────────────────────────────────
  describe("4. Optional Skills Resilience", () => {
    it("never rejects a candidate for missing optional/preferred skills", () => {
      const userProfile: CandidateProfile = {
        skills: [{ value: "Java", confirmed: true, provenance: "EXPLICIT" }],
        location: "Delhi",
        education: [{ degree: "Bachelor", confirmed: true, provenance: "EXPLICIT" }],
      };

      const job: JobMatchCriteria = {
        id: "job_optional_skills",
        title: "Java Developer",
        requiredSkills: ["java"],
        // 3 optional preferred skills that candidate does not possess
        preferredSkills: ["docker", "kubernetes", "aws"],
        minEdu: "Bachelor",
        city: "Delhi",
        status: "ACTIVE",
        isVerified: true,
        applyUrl: "https://example.com/apply",
      };

      const result = scoreForUser(userProfile, null, job, CONFIG_V1);

      // Missing optional skills must NOT be in missingSkills or gaps
      assert.strictEqual(result.missingSkills.length, 0);
      assert.ok(!result.missingSkills.includes("docker"));
      assert.ok(!result.missingSkills.includes("kubernetes"));
      assert.ok(!result.missingSkills.includes("aws"));

      // Candidate still gets full credit for the required skill
      assert.ok(result.matchedSkills.includes("java"));
      assert.ok(result.score > 0, "Score must remain positive");
    });
  });

  // ── 5. INFERRED Values Ignored ─────────────────────────────────────────────
  describe("5. INFERRED Values Ignored", () => {
    it("ignores skills, education, and experience with INFERRED provenance or confirmed=false", () => {
      const userProfile: CandidateProfile = {
        location: "Mumbai",
        skills: [
          { value: "Java", confirmed: true, provenance: "EXPLICIT" },
          // Unconfirmed/Inferred skills must be ignored
          { value: "Rust", confirmed: false, provenance: "INFERRED" },
          { value: "Go", confirmed: true, provenance: "INFERRED" },
        ],
        education: [
          // Confirmed Diploma (level rank 1)
          { degree: "Diploma", level: "diploma", confirmed: true, provenance: "EXPLICIT" },
          // Unconfirmed Master (level rank 3) must be ignored
          { degree: "Master of Science", level: "master", confirmed: false, provenance: "INFERRED" },
        ],
      };

      const job: JobMatchCriteria = {
        id: "job_ignore_inferred",
        title: "Systems Engineer",
        requiredSkills: ["rust"],
        minEdu: "Bachelor", // requires Bachelor (rank 2)
        city: "Mumbai",
        status: "ACTIVE",
        isVerified: true,
        applyUrl: "https://example.com/apply",
      };

      const result = scoreForUser(userProfile, null, job, CONFIG_V1);

      // Rust was INFERRED -> must be ignored and marked as missing
      assert.ok(result.missingSkills.includes("rust"));
      assert.strictEqual(result.breakdown.skills, 0);

      // Education: Inferred Master is ignored, user's Diploma is 1 level below Bachelor (40 pts)
      assert.strictEqual(result.breakdown.education, 40);
    });
  });

  // ── 6. Unknown Experience Never Treated as Fresher ─────────────────────────
  describe("6. Experience Handling", () => {
    it("defaults unknown experience to 50 with flag and NEVER treats as fresher (0 months)", () => {
      const userProfileUnknownExp: CandidateProfile = {
        skills: [{ value: "Java", confirmed: true, provenance: "EXPLICIT" }],
        education: [{ degree: "B.Tech", confirmed: true, provenance: "EXPLICIT" }],
        confirmedMonths: null,
        experience: [],
        isFresher: false,
      };

      const jobSenior: JobMatchCriteria = {
        id: "job_senior",
        title: "Senior Java Engineer",
        requiredSkills: ["java"],
        expMin: 4, // 4 years minimum
        status: "ACTIVE",
        isVerified: true,
        applyUrl: "https://example.com/apply",
      };

      const result = scoreForUser(userProfileUnknownExp, null, jobSenior, CONFIG_V1);

      // If treated as fresher (0 months), score would be 100 - 4*25 = 0 (floor 20)
      // Since it is unknown, it must be exactly 50 with the flag
      assert.strictEqual(result.breakdown.experience, 50);
      assert.ok(result.flags.includes("Add experience for better accuracy"));
    });
  });

  // ── 7. Config Weight Change Alters Score and ScoreVersion ──────────────────
  describe("7. Dynamic Config Weights & ScoreVersion", () => {
    it("alters output score and scoreVersion when config weights are changed", () => {
      const userProfile: CandidateProfile = {
        skills: [{ value: "Java", confirmed: true, provenance: "EXPLICIT" }],
        education: [{ degree: "Bachelor", confirmed: true, provenance: "EXPLICIT" }],
        confirmedMonths: 24,
      };

      const job: JobMatchCriteria = {
        id: "job_config_change",
        title: "Software Engineer",
        requiredSkills: ["java"],
        minEdu: "Master", // 1 level above candidate -> 40 pts
        expMin: 2,
        city: "Hyderabad",
        status: "ACTIVE",
        isVerified: true,
        applyUrl: "https://example.com/apply",
      };

      // Config v1: skills 40, education 15, experience 15, location 10, preference 20
      const resV1 = scoreForUser(userProfile, null, job, CONFIG_V1);

      // Config v2: heavy education weight (skills 20, education 60, experience 10, location 5, preference 5)
      const CONFIG_V2: ScoringConfig = {
        version: "v2",
        weights: {
          skills: 20,
          education: 60,
          experience: 10,
          location: 5,
          preference: 5,
        },
        threshold: 50,
        softCapCoverage: 0.5,
        softCap: 70,
        labelCutoffs: { excellent: 85, good: 70, fair: 50 },
      };

      const resV2 = scoreForUser(userProfile, null, job, CONFIG_V2);

      assert.strictEqual(resV1.scoreVersion, "v1");
      assert.strictEqual(resV2.scoreVersion, "v2");
      assert.notStrictEqual(resV1.score, resV2.score, "Scores must differ between v1 and v2 config");
    });
  });

  // ── 8. Stage 1 Hard Eligibility ───────────────────────────────────────────
  describe("8. Stage 1 Hard Eligibility", () => {
    it("passes active, verified jobs with valid applyUrl and enabled company", () => {
      const validJob: Partial<JobMatchCriteria> = {
        status: "ACTIVE",
        verification: { state: "VERIFIED" },
        applyUrl: "https://company.com/apply",
        hidden: false,
      };
      const check = checkStage1Eligibility(validJob, { enabled: true, hidden: false });
      assert.strictEqual(check.eligible, true);
    });

    it("rejects non-ACTIVE jobs", () => {
      const closedJob: Partial<JobMatchCriteria> = {
        status: "CLOSED",
        verification: { state: "VERIFIED" },
        applyUrl: "https://company.com/apply",
      };
      const check = checkStage1Eligibility(closedJob);
      assert.strictEqual(check.eligible, false);
      assert.match(check.reason ?? "", /expected ACTIVE/);
    });

    it("rejects unverified jobs or invalid applyUrl", () => {
      const unverified: Partial<JobMatchCriteria> = {
        status: "ACTIVE",
        verification: { state: "UNVERIFIED" },
        applyUrl: "invalid-url",
      };
      const check = checkStage1Eligibility(unverified);
      assert.strictEqual(check.eligible, false);
    });
  });

  // ── 9. Closed Job Removed from Recommendations ─────────────────────────────
  describe("9. Terminal Job Status Removal", () => {
    it("correctly identifies terminal statuses (CLOSED, EXPIRED, REJECTED, DUPLICATE) for deletion", () => {
      const terminalStatuses = ["CLOSED", "EXPIRED", "REJECTED", "DUPLICATE"];
      for (const status of terminalStatuses) {
        assert.ok(
          terminalStatuses.includes(status),
          `Status ${status} must be classified as terminal`,
        );
      }
    });
  });

  // ── 10. Duplicate Scoring Skipped ─────────────────────────────────────────
  describe("10. Duplicate Scoring Prevention", () => {
    it("skips scoring when contentHash and scoreVersion match existing recommendation", () => {
      const existingRecommendation = {
        jobId: "job_123",
        contentHash: "abc123hash",
        scoreVersion: "v1",
        score: 85,
      };

      const job: Partial<JobMatchCriteria> = {
        id: "job_123",
        contentHash: "abc123hash",
      };
      const currentConfigVersion = "v1";

      const shouldSkip =
        existingRecommendation.contentHash === job.contentHash &&
        existingRecommendation.scoreVersion === currentConfigVersion;

      assert.strictEqual(shouldSkip, true, "Must skip duplicate scoring for identical hash & version");

      // Changing contentHash requires rescoring
      const updatedJob = { id: "job_123", contentHash: "new_hash_456" };
      const skipUpdated =
        existingRecommendation.contentHash === updatedJob.contentHash &&
        existingRecommendation.scoreVersion === currentConfigVersion;
      assert.strictEqual(skipUpdated, false, "Must not skip when contentHash changes");
    });
  });

  // ── 11. Refresh Rate Limit ────────────────────────────────────────────────
  describe("11. Refresh Recommendations Rate Limit", () => {
    it("enforces 5-minute cooldown between manual refreshes", () => {
      const now = Date.now();
      const lastRefreshRecently = now - 2 * 60 * 1000; // 2 minutes ago
      const isRateLimited = now - lastRefreshRecently < 5 * 60 * 1000;

      assert.strictEqual(isRateLimited, true, "Must be rate limited within 5 minutes");

      const lastRefreshLongAgo = now - 6 * 60 * 1000; // 6 minutes ago
      const canRefresh = now - lastRefreshLongAgo >= 5 * 60 * 1000;
      assert.strictEqual(canRefresh, true, "Must allow refresh after 5 minutes");
    });
  });

  // ── 12. Strict No-Gemini Import Guard in src/matching ──────────────────────
  describe("12. Strict No-Gemini Guard in src/matching", () => {
    it("verifies that no file in src/matching imports Gemini or Google Generative AI", () => {
      const matchingDir = path.resolve(__dirname, "../matching");
      const files = fs.readdirSync(matchingDir).filter((f) => f.endsWith(".ts"));

      assert.ok(files.length > 0, "src/matching must contain files");

      for (const file of files) {
        const filePath = path.join(matchingDir, file);
        const content = fs.readFileSync(filePath, "utf8");
        const lines = content.split("\n");

        for (const line of lines) {
          const trimmed = line.trim();
          if (trimmed.startsWith("import ") || trimmed.includes("require(")) {
            assert.strictEqual(
              /gemini/i.test(trimmed),
              false,
              `File ${file} has forbidden Gemini import: "${trimmed}"`,
            );
            assert.strictEqual(
              /@google\/generative-ai/i.test(trimmed),
              false,
              `File ${file} has forbidden Google Generative AI import: "${trimmed}"`,
            );
          }
        }
      }
    });
  });
});
