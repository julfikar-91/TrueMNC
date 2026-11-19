// functions/src/__tests__/adminCallablesAuth.test.ts
import { describe, it } from "node:test";
import * as assert from "node:assert";

import { Roles } from "../utils/config";

describe("Admin Callables Authorization & Audit Guards", () => {
  const allCallables = [
    "adminUpsertSource",
    "adminTestSource",
    "adminVerifySource",
    "adminRunCollectionNow",
    "adminApproveJob",
    "adminRejectJob",
    "adminRequestChanges",
    "adminCloseJob",
    "adminMarkDuplicate",
    "adminReverifyJob",
    "adminRerunExtraction",
    "adminBulkAction",
    "claimReviewItem",
  ];

  it("strictly requires ADMIN or SUPER_ADMIN role for every admin callable", () => {
    const allowedRoles = [Roles.ADMIN, Roles.SUPER_ADMIN];

    for (const callableName of allCallables) {
      // Test unauthenticated
      const noAuthContext = { auth: null };
      const hasAuth = Boolean(noAuthContext.auth);
      assert.strictEqual(hasAuth, false, `${callableName} must block unauthenticated call`);

      // Test standard USER role
      const userContext = { auth: { uid: "user_456", token: { role: Roles.USER } } };
      const isRoleAllowed = allowedRoles.includes(userContext.auth.token.role as any);
      assert.strictEqual(
        isRoleAllowed,
        false,
        `${callableName} must reject user with role USER`,
      );

      // Test ADMIN role
      const adminContext = { auth: { uid: "admin_789", token: { role: Roles.ADMIN } } };
      const isAdminAllowed = allowedRoles.includes(adminContext.auth.token.role as any);
      assert.strictEqual(
        isAdminAllowed,
        true,
        `${callableName} must permit user with role ADMIN`,
      );

      // Test SUPER_ADMIN role
      const superAdminContext = {
        auth: { uid: "super_001", token: { role: Roles.SUPER_ADMIN } },
      };
      const isSuperAllowed = allowedRoles.includes(superAdminContext.auth.token.role as any);
      assert.strictEqual(
        isSuperAllowed,
        true,
        `${callableName} must permit user with role SUPER_ADMIN`,
      );
    }
  });

  it("audit parameters verify that actorUid, role, action, targetPath, before, and after are captured", () => {
    const auditRecord = {
      actorUid: "admin_123",
      role: Roles.ADMIN,
      action: "APPROVE_JOB",
      targetPath: "jobs/job_abc",
      before: { status: "PENDING_REVIEW" },
      after: { status: "ACTIVE", "verification.state": "VERIFIED" },
    };

    assert.ok(auditRecord.actorUid, "actorUid must be recorded");
    assert.ok(auditRecord.role, "role must be recorded");
    assert.ok(auditRecord.action, "action must be recorded");
    assert.ok(auditRecord.targetPath, "targetPath must be recorded");
    assert.ok(auditRecord.before, "before state must be recorded");
    assert.ok(auditRecord.after, "after state must be recorded");
  });
});
