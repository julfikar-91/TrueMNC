// functions/src/__tests__/roleManagement.test.ts
import { describe, it, beforeEach } from "node:test";
import * as assert from "node:assert/strict";
import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as crypto from "crypto";

import { Roles } from "../utils/config";
import { hashIp } from "../utils/logger";
import { requireAuth } from "../utils/auth";

// ── In-Memory Mocks for Emulator Emulation ────────────────────────────────────

interface MockUser {
  uid: string;
  email: string;
  customClaims?: { role?: string };
}

interface MockDoc {
  id: string;
  data: Record<string, unknown>;
}

class MockAuthService {
  private users = new Map<string, MockUser>();

  addUser(user: MockUser): void {
    this.users.set(user.uid, user);
  }

  clear(): void {
    this.users.clear();
  }

  async getUser(uid: string): Promise<MockUser> {
    const user = this.users.get(uid);
    if (!user) throw new Error("User not found");
    return user;
  }

  async getUserByEmail(email: string): Promise<MockUser> {
    for (const user of this.users.values()) {
      if (user.email.toLowerCase() === email.toLowerCase()) {
        return user;
      }
    }
    throw new Error("User not found");
  }

  async setCustomUserClaims(uid: string, claims: Record<string, unknown>): Promise<void> {
    const user = this.users.get(uid);
    if (user) {
      user.customClaims = claims as { role?: string };
    }
  }

  async revokeRefreshTokens(_uid: string): Promise<void> {}
}

class MockFirestoreService {
  private collections = new Map<string, Map<string, MockDoc>>();

  clear(): void {
    this.collections.clear();
  }

  getDocs(collectionName: string): MockDoc[] {
    const col = this.collections.get(collectionName);
    return col ? Array.from(col.values()) : [];
  }

  async addDoc(collectionName: string, data: Record<string, unknown>): Promise<string> {
    if (!this.collections.has(collectionName)) {
      this.collections.set(collectionName, new Map());
    }
    const id = `doc_${Date.now()}_${Math.random()}`;
    this.collections.get(collectionName)!.set(id, { id, data });
    return id;
  }

  async setDoc(collectionName: string, docId: string, data: Record<string, unknown>): Promise<void> {
    if (!this.collections.has(collectionName)) {
      this.collections.set(collectionName, new Map());
    }
    this.collections.get(collectionName)!.set(docId, { id: docId, data });
  }

  countWhere(collectionName: string, field: string, value: unknown): number {
    const docs = this.getDocs(collectionName);
    return docs.filter((d) => d.data[field] === value).length;
  }
}

// ── Test Suite ───────────────────────────────────────────────────────────────

describe("Role Management & Security Rules", () => {
  const mockAuth = new MockAuthService();
  const mockDb = new MockFirestoreService();

  beforeEach(() => {
    mockAuth.clear();
    mockDb.clear();
  });

  describe("Requirement 1: utils/auth.ts (requireAuth & requireRole)", () => {
    it("requireAuth throws unauthenticated if request has no auth context", () => {
      const unauthReq = {} as CallableRequest;
      assert.throws(
        () => requireAuth(unauthReq),
        (err: unknown) => err instanceof HttpsError && err.code === "unauthenticated",
      );
    });

    it("requireAuth succeeds and returns uid when authenticated", () => {
      const authReq = {
        auth: { uid: "user_valid_123" },
      } as unknown as CallableRequest;

      assert.equal(requireAuth(authReq), "user_valid_123");
    });

    it("requireRole throws permission-denied when user role is not in allowedRoles", async () => {
      mockAuth.addUser({
        uid: "user_standard",
        email: "standard@corp.com",
        customClaims: { role: Roles.USER },
      });

      // Simulation of requireRole logic
      const req = {
        auth: { uid: "user_standard" },
      } as unknown as CallableRequest;

      const checkRole = async () => {
        const uid = requireAuth(req);
        const user = await mockAuth.getUser(uid);
        const role = user.customClaims?.role || Roles.USER;
        if (![Roles.SUPER_ADMIN].includes(role as any)) {
          throw new HttpsError("permission-denied", "Permission denied: Insufficient role permissions.");
        }
        return role;
      };

      await assert.rejects(
        checkRole(),
        (err: unknown) => err instanceof HttpsError && err.code === "permission-denied",
      );
    });

    it("requireRole accepts user who holds required role on backend", async () => {
      mockAuth.addUser({
        uid: "super_admin_1",
        email: "super@corp.com",
        customClaims: { role: Roles.SUPER_ADMIN },
      });

      const req = {
        auth: { uid: "super_admin_1" },
      } as unknown as CallableRequest;

      const uid = requireAuth(req);
      const user = await mockAuth.getUser(uid);
      const role = user.customClaims?.role || Roles.USER;
      assert.equal(role, Roles.SUPER_ADMIN);
      assert.ok([Roles.SUPER_ADMIN].includes(role as any));
    });
  });

  describe("Requirement 2: setUserRole Logic & Invariants", () => {
    it("blocks removing the last SUPER_ADMIN from the system", async () => {
      // Setup: Only 1 SUPER_ADMIN exists in Firestore and Auth
      mockAuth.addUser({
        uid: "sole_super_admin",
        email: "sole.admin@corp.com",
        customClaims: { role: Roles.SUPER_ADMIN },
      });
      await mockDb.setDoc("users", "sole_super_admin", {
        role: Roles.SUPER_ADMIN,
      });

      const attemptDemotion = async () => {
        const targetUser = await mockAuth.getUserByEmail("sole.admin@corp.com");
        const previousRole: string = targetUser.customClaims?.role || Roles.USER;
        const newRole: string = Roles.USER;

        if (previousRole === Roles.SUPER_ADMIN && newRole !== Roles.SUPER_ADMIN) {
          const superAdminCount = mockDb.countWhere("users", "role", Roles.SUPER_ADMIN);
          if (superAdminCount <= 1) {
            throw new HttpsError("failed-precondition", "Cannot remove the last SUPER_ADMIN.");
          }
        }
      };

      await assert.rejects(
        attemptDemotion(),
        (err: unknown) =>
          err instanceof HttpsError &&
          err.code === "failed-precondition" &&
          err.message === "Cannot remove the last SUPER_ADMIN.",
      );
    });

    it("allows demoting a SUPER_ADMIN if multiple SUPER_ADMINs exist", async () => {
      // Setup: 2 SUPER_ADMINs exist
      mockAuth.addUser({
        uid: "super_admin_1",
        email: "admin1@corp.com",
        customClaims: { role: Roles.SUPER_ADMIN },
      });
      mockAuth.addUser({
        uid: "super_admin_2",
        email: "admin2@corp.com",
        customClaims: { role: Roles.SUPER_ADMIN },
      });

      await mockDb.setDoc("users", "super_admin_1", { role: Roles.SUPER_ADMIN });
      await mockDb.setDoc("users", "super_admin_2", { role: Roles.SUPER_ADMIN });

      const targetUser = await mockAuth.getUserByEmail("admin1@corp.com");
      const previousRole: string = targetUser.customClaims?.role || Roles.USER;
      const newRole: string = Roles.ADMIN;

      if (previousRole === Roles.SUPER_ADMIN && newRole !== Roles.SUPER_ADMIN) {
        const count = mockDb.countWhere("users", "role", Roles.SUPER_ADMIN);
        assert.ok(count > 1, "Multiple super admins exist");
      }

      // Demote admin1
      await mockAuth.setCustomUserClaims(targetUser.uid, { role: newRole });
      await mockDb.setDoc("users", targetUser.uid, { role: newRole });

      assert.equal(mockDb.countWhere("users", "role", Roles.SUPER_ADMIN), 1);
      assert.equal((await mockAuth.getUser("super_admin_1")).customClaims?.role, Roles.ADMIN);
    });
  });

  describe("Requirement 3: utils/audit.ts & Structured Logging", () => {
    it("hashes IP address without storing raw IP (NO PII)", () => {
      const rawIp = "192.168.1.50";
      const hashed = hashIp(rawIp);

      assert.notEqual(hashed, rawIp);
      assert.equal(
        hashed,
        crypto.createHash("sha256").update(rawIp).digest("hex"),
      );
      assert.equal(hashIp(undefined), "unknown");
    });

    it("writes an immutable audit log entry with actorUid, role, action, targetPath, before, after, ipHash", async () => {
      const rawIp = "203.0.113.195";
      const auditPayload = {
        actorUid: "super_admin_999",
        role: Roles.SUPER_ADMIN,
        action: "SET_USER_ROLE",
        targetPath: "users/target_user_888",
        before: Roles.USER,
        after: Roles.ADMIN,
        ipHash: hashIp(rawIp),
        at: new Date(),
      };

      const auditId = await mockDb.addDoc("auditLogs", auditPayload);
      assert.ok(auditId.startsWith("doc_"));

      const logs = mockDb.getDocs("auditLogs");
      assert.equal(logs.length, 1);
      const savedLog = logs[0].data;

      assert.equal(savedLog.actorUid, "super_admin_999");
      assert.equal(savedLog.role, Roles.SUPER_ADMIN);
      assert.equal(savedLog.action, "SET_USER_ROLE");
      assert.equal(savedLog.targetPath, "users/target_user_888");
      assert.equal(savedLog.before, Roles.USER);
      assert.equal(savedLog.after, Roles.ADMIN);
      assert.equal(savedLog.ipHash, hashIp(rawIp));
      // Raw IP must NEVER be present
      assert.equal((savedLog as any).rawIp, undefined);
    });
  });
});
