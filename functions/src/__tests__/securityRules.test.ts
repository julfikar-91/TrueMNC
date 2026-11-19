// functions/src/__tests__/securityRules.test.ts
import { describe, it, before, after, beforeEach } from "node:test";
import * as assert from "node:assert/strict";
import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "truemnc-rules-test";

describe("Firebase Security Rules Suite (Firestore & Storage)", () => {
  let testEnv: RulesTestEnvironment;

  before(async () => {
    // Resolve rules files from workspace root
    const firestoreRulesPath = path.resolve(__dirname, "../../../firestore.rules");
    const storageRulesPath = path.resolve(__dirname, "../../../storage.rules");

    const firestoreRules = fs.readFileSync(firestoreRulesPath, "utf8");
    const storageRules = fs.readFileSync(storageRulesPath, "utf8");

    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: firestoreRules,
        host: process.env.FIRESTORE_EMULATOR_HOST?.split(":")[0] || "127.0.0.1",
        port: Number(process.env.FIRESTORE_EMULATOR_HOST?.split(":")[1]) || 8080,
      },
      storage: {
        rules: storageRules,
        host: process.env.FIREBASE_STORAGE_EMULATOR_HOST?.split(":")[0] || "127.0.0.1",
        port: Number(process.env.FIREBASE_STORAGE_EMULATOR_HOST?.split(":")[1]) || 9199,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
      await testEnv.clearStorage();
    }
  });

  // ── 1. User cannot set role or server-controlled fields ───────────────────
  describe("1. User cannot set role", () => {
    it("owner cannot set 'role' when creating their user document", async () => {
      const aliceContext = testEnv.authenticatedContext("alice");
      const aliceDb = aliceContext.firestore();

      // Attempting to inject role: 'ADMIN' on creation
      const maliciousDoc = aliceDb.collection("users").doc("alice");
      await assertFails(
        maliciousDoc.set({
          name: "Alice",
          email: "alice@corporate.com",
          role: "ADMIN", // Forbidden
        }),
      );
    });

    it("owner can create user document when 'role' is omitted", async () => {
      const aliceContext = testEnv.authenticatedContext("alice");
      const aliceDb = aliceContext.firestore();

      const validDoc = aliceDb.collection("users").doc("alice");
      await assertSucceeds(
        validDoc.set({
          name: "Alice",
          email: "alice@corporate.com",
          onboarding_done: false,
          profile_confirmed: false,
        }),
      );
    });

    it("owner cannot update role, profile_confirmed_by_system, profile_completion, or matchKeys", async () => {
      // Seed existing valid document via admin bypass
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("users").doc("alice").set({
          name: "Alice",
          email: "alice@corporate.com",
          role: "USER",
          profile_confirmed_by_system: false,
          profile_completion: 50,
          matchKeys: ["flutter"],
        });
      });

      const aliceContext = testEnv.authenticatedContext("alice");
      const aliceDb = aliceContext.firestore();
      const aliceRef = aliceDb.collection("users").doc("alice");

      // Attempting to elevate role
      await assertFails(aliceRef.update({ role: "SUPER_ADMIN" }));

      // Attempting to manipulate profile_confirmed_by_system
      await assertFails(aliceRef.update({ profile_confirmed_by_system: true }));

      // Attempting to manipulate profile_completion
      await assertFails(aliceRef.update({ profile_completion: 100 }));

      // Attempting to manipulate matchKeys
      await assertFails(aliceRef.update({ matchKeys: ["executive"] }));

      // Updating legitimate profile field succeeds
      await assertSucceeds(aliceRef.update({ name: "Alice Smith" }));
    });
  });

  // ── 2. User cannot read another user's doc or resume ─────────────────────
  describe("2. Cannot read another user's doc or resume", () => {
    it("alice cannot read bob's user document; admin can read", async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("users").doc("bob").set({
          name: "Bob",
          email: "bob@corporate.com",
        });
      });

      const aliceContext = testEnv.authenticatedContext("alice");
      await assertFails(aliceContext.firestore().collection("users").doc("bob").get());

      const adminContext = testEnv.authenticatedContext("charlie_admin", {
        role: "ADMIN",
      });
      await assertSucceeds(adminContext.firestore().collection("users").doc("bob").get());
    });

    it("alice cannot read or delete bob's resume; bob can read and delete", async () => {
      // Seed Bob's resume in storage via rules bypass
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const bobFile = context.storage().ref("resumes/bob/resume.pdf");
        await bobFile.putString("Sample PDF content", "raw", {
          contentType: "application/pdf",
        });
      });

      const aliceContext = testEnv.authenticatedContext("alice");
      const aliceStorage = aliceContext.storage();
      await assertFails(aliceStorage.ref("resumes/bob/resume.pdf").getDownloadURL());
      await assertFails(aliceStorage.ref("resumes/bob/resume.pdf").delete());

      const bobContext = testEnv.authenticatedContext("bob");
      const bobStorage = bobContext.storage();
      await assertSucceeds(bobStorage.ref("resumes/bob/resume.pdf").getDownloadURL());
      await assertSucceeds(bobStorage.ref("resumes/bob/resume.pdf").delete());
    });
  });

  // ── 3. Client cannot write jobs ──────────────────────────────────────────
  describe("3. Cannot write jobs", () => {
    it("regular user and admin cannot write to jobs collection (write false)", async () => {
      const aliceContext = testEnv.authenticatedContext("alice");
      await assertFails(
        aliceContext.firestore().collection("jobs").doc("job_1").set({
          title: "Senior Engineer",
          status: "ACTIVE",
          verification: { state: "VERIFIED" },
        }),
      );

      const adminContext = testEnv.authenticatedContext("charlie_admin", {
        role: "SUPER_ADMIN",
      });
      await assertFails(
        adminContext.firestore().collection("jobs").doc("job_1").set({
          title: "Staff Engineer",
          status: "ACTIVE",
          verification: { state: "VERIFIED" },
        }),
      );
    });
  });

  // ── 4. Guest can read only ACTIVE+VERIFIED jobs ──────────────────────────
  describe("4. Guest can read only ACTIVE+VERIFIED jobs", () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        // 1. Active + Verified
        await db.collection("jobs").doc("active_verified").set({
          title: "Mobile Architect",
          status: "ACTIVE",
          verification: { state: "VERIFIED" },
        });
        // 2. Draft + Verified
        await db.collection("jobs").doc("draft_verified").set({
          title: "Draft Job",
          status: "DRAFT",
          verification: { state: "VERIFIED" },
        });
        // 3. Active + Unverified
        await db.collection("jobs").doc("active_unverified").set({
          title: "Unverified Job",
          status: "ACTIVE",
          verification: { state: "UNVERIFIED" },
        });
      });
    });

    it("guest can read active and verified jobs", async () => {
      const guestContext = testEnv.unauthenticatedContext();
      await assertSucceeds(
        guestContext.firestore().collection("jobs").doc("active_verified").get(),
      );
    });

    it("guest cannot read draft or unverified jobs", async () => {
      const guestContext = testEnv.unauthenticatedContext();
      await assertFails(
        guestContext.firestore().collection("jobs").doc("draft_verified").get(),
      );
      await assertFails(
        guestContext.firestore().collection("jobs").doc("active_unverified").get(),
      );
    });

    it("admin can read jobs regardless of verification or status", async () => {
      const adminContext = testEnv.authenticatedContext("admin_user", {
        role: "ADMIN",
      });
      await assertSucceeds(
        adminContext.firestore().collection("jobs").doc("draft_verified").get(),
      );
      await assertSucceeds(
        adminContext.firestore().collection("jobs").doc("active_unverified").get(),
      );
    });

    it("guest can read companies", async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("companies").doc("google").set({
          name: "Google LLC",
        });
      });
      const guestContext = testEnv.unauthenticatedContext();
      await assertSucceeds(
        guestContext.firestore().collection("companies").doc("google").get(),
      );
    });
  });

  // ── 5. Admin-only collections ────────────────────────────────────────────
  describe("5. Admin-only collections & subcollections", () => {
    it("auditLogs: admin can read, user/guest cannot; write is denied to all", async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("auditLogs").doc("log_1").set({
          action: "SET_USER_ROLE",
          actorUid: "admin",
        });
      });

      const guestContext = testEnv.unauthenticatedContext();
      await assertFails(guestContext.firestore().collection("auditLogs").doc("log_1").get());

      const userContext = testEnv.authenticatedContext("alice");
      await assertFails(userContext.firestore().collection("auditLogs").doc("log_1").get());

      const adminContext = testEnv.authenticatedContext("super_admin", {
        role: "SUPER_ADMIN",
      });
      await assertSucceeds(adminContext.firestore().collection("auditLogs").doc("log_1").get());

      // Write is false even for admin
      await assertFails(
        adminContext.firestore().collection("auditLogs").doc("log_2").set({
          action: "MANUAL_INJECTION",
        }),
      );
    });

    it("users/{uid}/recommendations: owner can read but cannot write", async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .collection("users")
          .doc("alice")
          .collection("recommendations")
          .doc("job_100")
          .set({ score: 0.95 });
      });

      const aliceContext = testEnv.authenticatedContext("alice");
      const recRef = aliceContext
        .firestore()
        .collection("users")
        .doc("alice")
        .collection("recommendations")
        .doc("job_100");

      // Owner read succeeds
      await assertSucceeds(recRef.get());

      // Owner write fails
      await assertFails(recRef.set({ score: 1.0 }));

      // Other user read fails
      const bobContext = testEnv.authenticatedContext("bob");
      await assertFails(
        bobContext
          .firestore()
          .collection("users")
          .doc("alice")
          .collection("recommendations")
          .doc("job_100")
          .get(),
      );
    });

    it("arbitrary collection is denied by default", async () => {
      const userContext = testEnv.authenticatedContext("alice");
      await assertFails(userContext.firestore().collection("unlisted_collection").doc("doc_1").get());
      await assertFails(
        userContext.firestore().collection("unlisted_collection").doc("doc_1").set({ a: 1 }),
      );
    });
  });

  // ── 6. Storage: oversize/wrong-type upload rejected ──────────────────────
  describe("6. Storage: oversize / wrong-type uploads rejected", () => {
    it("resumes: allows PDF and DOCX under 2MB; rejects images and files >= 2MB", async () => {
      const aliceContext = testEnv.authenticatedContext("alice");
      const storage = aliceContext.storage();

      const validPdfRef = storage.ref("resumes/alice/cv.pdf");
      const validDocxRef = storage.ref("resumes/alice/cv.docx");
      const invalidImageRef = storage.ref("resumes/alice/photo.png");
      const oversizeRef = storage.ref("resumes/alice/heavy.pdf");

      // 100 KB valid PDF
      const smallPdf = new Uint8Array(100 * 1024);
      await assertSucceeds(
        validPdfRef.put(smallPdf, { contentType: "application/pdf" }),
      );

      // 100 KB valid DOCX
      const smallDocx = new Uint8Array(100 * 1024);
      await assertSucceeds(
        validDocxRef.put(smallDocx, {
          contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        }),
      );

      // Reject image in resumes path
      const smallImage = new Uint8Array(50 * 1024);
      await assertFails(
        invalidImageRef.put(smallImage, { contentType: "image/png" }),
      );

      // Reject oversize (> 2MB: 2.1 MB)
      const bigFile = new Uint8Array(2.1 * 1024 * 1024);
      await assertFails(
        oversizeRef.put(bigFile, { contentType: "application/pdf" }),
      );
    });

    it("avatars: allows images under 2MB with public read; rejects PDFs", async () => {
      const aliceContext = testEnv.authenticatedContext("alice");
      const avatarRef = aliceContext.storage().ref("avatars/alice/avatar.jpg");
      const fakePdfAvatarRef = aliceContext.storage().ref("avatars/alice/avatar.pdf");

      const smallImage = new Uint8Array(80 * 1024);
      await assertSucceeds(
        avatarRef.put(smallImage, { contentType: "image/jpeg" }),
      );

      // Rejects non-image
      await assertFails(
        fakePdfAvatarRef.put(smallImage, { contentType: "application/pdf" }),
      );

      // Public read succeeds
      const guestContext = testEnv.unauthenticatedContext();
      await assertSucceeds(
        guestContext.storage().ref("avatars/alice/avatar.jpg").getDownloadURL(),
      );
    });

    it("reports: owner write succeeds; reading is denied to everyone", async () => {
      const aliceContext = testEnv.authenticatedContext("alice");
      const reportRef = aliceContext.storage().ref("reports/alice/incident.txt");

      // Owner write succeeds
      await assertSucceeds(
        reportRef.putString("Suspicious listing details", "raw", {
          contentType: "text/plain",
        }),
      );

      // Read is false even for owner
      await assertFails(reportRef.getDownloadURL());
    });
  });
});
