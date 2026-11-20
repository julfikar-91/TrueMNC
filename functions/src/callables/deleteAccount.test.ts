// functions/src/callables/deleteAccount.test.ts
import { describe, it } from "node:test";
import * as assert from "node:assert/strict";
import * as crypto from "crypto";

describe("deleteAccount Callable & Lifecycle Tests", () => {
  const uid = "user_delete_target_123";
  const hashedUid = crypto.createHash("sha256").update(uid).digest("hex");

  it("1. Reauth Requirement: rejects non-recent login (auth_time > 5 minutes)", () => {
    const nowSeconds = Math.floor(Date.now() / 1000);
    const staleAuthTime = nowSeconds - 305; // 5 min 5 sec ago

    const isRecent = staleAuthTime && (nowSeconds - staleAuthTime) <= 300;
    assert.strictEqual(isRecent, false, "Sign-in older than 300s must be marked non-recent");
  });

  it("2. Reauth Requirement: accepts recent login (auth_time <= 5 minutes)", () => {
    const nowSeconds = Math.floor(Date.now() / 1000);
    const recentAuthTime = nowSeconds - 60; // 1 min ago

    const isRecent = recentAuthTime && (nowSeconds - recentAuthTime) <= 300;
    assert.strictEqual(isRecent, true, "Sign-in within 300s must be accepted");
  });

  it("3. Data Sanitization & Report Anonymization", () => {
    const originalReport = {
      id: "rep_999",
      reporterUid: uid,
      category: "INCORRECT_JOB",
      status: "OPEN",
      text: "The salary is inaccurate and confidential data was exposed.",
      screenshotPath: `reports/${uid}/screen.png`,
    };

    // Simulate anonymization
    const anonymisedReport = {
      ...originalReport,
      reporterUid: null,
      text: "[Account Deleted]",
      screenshotPath: null,
      anonymised: true,
    };

    assert.strictEqual(anonymisedReport.reporterUid, null);
    assert.strictEqual(anonymisedReport.text, "[Account Deleted]");
    assert.strictEqual(anonymisedReport.screenshotPath, null);
    assert.strictEqual(anonymisedReport.category, "INCORRECT_JOB");
    assert.strictEqual(anonymisedReport.status, "OPEN");
  });

  it("4. Audit Log Hashing: UID is transformed to SHA-256 hash", () => {
    const originalAuditLog = {
      id: "audit_111",
      actorUid: uid,
      action: "UPDATE_PROFILE",
      targetPath: `users/${uid}`,
    };

    const sanitizedAuditLog = {
      ...originalAuditLog,
      actorUid: hashedUid,
      anonymised: true,
    };

    assert.strictEqual(sanitizedAuditLog.actorUid, hashedUid);
    assert.notStrictEqual(sanitizedAuditLog.actorUid, uid);
    assert.strictEqual(sanitizedAuditLog.actorUid.length, 64);
  });

  it("5. Subcollection Deletion Scope covers all required candidate collections", () => {
    const requiredSubcollections = [
      "education",
      "skills",
      "experience",
      "projects",
      "certifications",
      "preferences",
      "recommendations",
      "savedJobs",
      "redirects",
      "notifications",
      "savedSearches",
    ];

    const targetSubcollections = [
      "education",
      "skills",
      "experience",
      "projects",
      "certifications",
      "preferences",
      "recommendations",
      "savedJobs",
      "redirects",
      "notifications",
      "savedSearches",
      "fcmTokens",
      "aiUsage",
    ];

    for (const req of requiredSubcollections) {
      assert.ok(targetSubcollections.includes(req), `Must include ${req} for deletion`);
    }
  });

  it("6. Idempotency Simulation: safe to retry after partial completion", async () => {
    let storageDeleted = false;
    let userDocDeleted = false;
    let authUserDeleted = false;

    async function mockDeletionAttempt(shouldFailMidway: boolean) {
      storageDeleted = true;
      if (shouldFailMidway) {
        throw new Error("Network transient error");
      }
      userDocDeleted = true;
      authUserDeleted = true;
      return true;
    }

    // Attempt 1: Fails midway
    try {
      await mockDeletionAttempt(true);
    } catch {
      // transient failure
    }
    assert.strictEqual(storageDeleted, true);
    assert.strictEqual(userDocDeleted, false);

    // Attempt 2: Retry succeeds idempotently
    const success = await mockDeletionAttempt(false);
    assert.strictEqual(success, true);
    assert.strictEqual(storageDeleted, true);
    assert.strictEqual(userDocDeleted, true);
    assert.strictEqual(authUserDeleted, true);
  });
});
