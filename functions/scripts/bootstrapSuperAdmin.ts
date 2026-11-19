// functions/scripts/bootstrapSuperAdmin.ts
/**
 * One-time bootstrap script (Emulator / Development only).
 * Sets the initial SUPER_ADMIN role for a designated corporate administrator.
 *
 * Usage:
 *   npx ts-node scripts/bootstrapSuperAdmin.ts admin@truecorporate.com
 */

import * as admin from "firebase-admin";
import * as crypto from "crypto";

// Ensure Firebase Admin is initialized
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || "truemnc-dev",
  });
}

const auth = admin.auth();
const db = admin.firestore();

function maskEmail(email: string): string {
  const [user, domain] = email.split("@");
  if (user.length <= 2) return `*@${domain}`;
  return `${user[0]}***${user[user.length - 1]}@${domain}`;
}

async function bootstrapSuperAdmin(): Promise<void> {
  const isEmulator =
    Boolean(process.env.FUNCTIONS_EMULATOR) ||
    Boolean(process.env.FIRESTORE_EMULATOR_HOST) ||
    process.env.NODE_ENV === "development" ||
    process.env.NODE_ENV === "test";

  if (!isEmulator && process.env.NODE_ENV === "production") {
    console.error("FATAL: bootstrapSuperAdmin script cannot be run in production directly.");
    process.exit(1);
  }

  const emailArg = process.argv[2] || process.env.BOOTSTRAP_SUPER_ADMIN_EMAIL;
  if (!emailArg || !emailArg.includes("@")) {
    console.error("Usage: npx ts-node scripts/bootstrapSuperAdmin.ts <corporate-email>");
    process.exit(1);
  }

  const targetEmail = emailArg.trim().toLowerCase();
  console.log(`[BOOTSTRAP] Initialising SUPER_ADMIN for target: ${maskEmail(targetEmail)}`);

  try {
    let userRecord: admin.auth.UserRecord;

    try {
      userRecord = await auth.getUserByEmail(targetEmail);
    } catch {
      console.log(`[BOOTSTRAP] User not found. Creating user account for ${maskEmail(targetEmail)}...`);
      userRecord = await auth.createUser({
        email: targetEmail,
        emailVerified: true,
        displayName: "System Super Admin",
      });
    }

    // 1. Assign SUPER_ADMIN custom claim
    await auth.setCustomUserClaims(userRecord.uid, {
      ...(userRecord.customClaims || {}),
      role: "SUPER_ADMIN",
    });

    // 2. Mirror role to users/{uid} document
    await db.collection("users").doc(userRecord.uid).set(
      {
        email: targetEmail,
        role: "SUPER_ADMIN",
        onboarding_done: true,
        profile_confirmed: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    // 3. Write immutable bootstrap audit log
    await db.collection("auditLogs").add({
      actorUid: "SYSTEM_BOOTSTRAP",
      role: "SUPER_ADMIN",
      action: "BOOTSTRAP_SUPER_ADMIN",
      targetPath: `users/${userRecord.uid}`,
      before: userRecord.customClaims?.role ?? null,
      after: "SUPER_ADMIN",
      at: admin.firestore.FieldValue.serverTimestamp(),
      ipHash: crypto.createHash("sha256").update("127.0.0.1").digest("hex"),
      metadata: {
        script: "bootstrapSuperAdmin.ts",
        targetUid: userRecord.uid,
      },
    });

    console.log(`[BOOTSTRAP] SUCCESS: Assigned SUPER_ADMIN role to UID: ${userRecord.uid}`);
    process.exit(0);
  } catch (err) {
    console.error("[BOOTSTRAP] Failed to bootstrap Super Admin:", err);
    process.exit(1);
  }
}

void bootstrapSuperAdmin();
