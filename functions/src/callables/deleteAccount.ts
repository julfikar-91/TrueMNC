// functions/src/callables/deleteAccount.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { writeAudit } from "../utils/audit";
import { logInfo, logError } from "../utils/logger";
import { validate } from "../utils/validators";

const FN = "deleteAccount";

export const DeleteAccountInputSchema = z.object({}).optional();

export const USER_SUBCOLLECTIONS = [
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
] as const;

/**
 * Executes full account deletion idempotently.
 * Safe to retry upon partial failure.
 */
export async function executeAccountDeletion(uid: string, rawIp?: string): Promise<{
  success: boolean;
  deletedSubcollectionsCount: number;
  anonymisedReportsCount: number;
  deletedResumesCount: number;
}> {
  const hashedUid = crypto.createHash("sha256").update(uid).digest("hex");
  let deletedSubcollectionsCount = 0;
  let anonymisedReportsCount = 0;
  let deletedResumesCount = 0;

  // 1. Storage files deletion (resumes/{uid}/*, avatars/{uid}/*)
  try {
    const bucket = admin.storage().bucket();
    await Promise.allSettled([
      bucket.deleteFiles({ prefix: `resumes/${uid}/`, force: true }),
      bucket.deleteFiles({ prefix: `avatars/${uid}/`, force: true }),
    ]);
  } catch (err) {
    // Non-fatal, proceed with firestore cleanup
    logError(FN, "Error clearing storage files", { uidHash: hashedUid });
  }

  // 2. Delete user subcollections via BulkWriter
  const bulkWriter = db().bulkWriter();
  bulkWriter.onWriteError((error) => {
    return error.failedAttempts < 3;
  });

  for (const sub of USER_SUBCOLLECTIONS) {
    try {
      const snap = await db()
        .collection(Collections.USERS)
        .doc(uid)
        .collection(sub)
        .get();

      for (const doc of snap.docs) {
        bulkWriter.delete(doc.ref);
        deletedSubcollectionsCount++;
      }
    } catch {
      // Continue next subcollection
    }
  }
  await bulkWriter.close();

  // 3. Delete resumes and resumeParses documents owned by uid
  const ownedCollections = ["resumes", "resumeParses", "fcmTokens"];
  for (const col of ownedCollections) {
    try {
      const snap = await db().collection(col).where("uid", "==", uid).get();
      for (const doc of snap.docs) {
        await doc.ref.delete();
        deletedResumesCount++;
      }
    } catch {
      // Proceed idempotently
    }
  }

  // 4. Anonymise reports: remove reporterUid and text, keep category & status
  try {
    const reportsSnap = await db()
      .collection(Collections.REPORTS)
      .where("reporterUid", "==", uid)
      .get();

    for (const doc of reportsSnap.docs) {
      await doc.ref.update({
        reporterUid: null,
        text: "[Account Deleted]",
        screenshotPath: null,
        anonymised: true,
        anonymisedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      anonymisedReportsCount++;
    }
  } catch {
    // Proceed idempotently
  }

  // 5. Keep auditLogs with hashed uid only
  try {
    const auditSnap = await db()
      .collection(Collections.AUDIT_LOGS)
      .where("actorUid", "==", uid)
      .get();

    for (const doc of auditSnap.docs) {
      await doc.ref.update({
        actorUid: hashedUid,
        anonymised: true,
      });
    }
  } catch {
    // Proceed idempotently
  }

  // 6. Delete users/{uid} root document
  try {
    await db().collection(Collections.USERS).doc(uid).delete();
  } catch {
    // Already deleted
  }

  // 7. Write audit log entry with hashed UID
  try {
    await writeAudit({
      actorUid: hashedUid,
      role: "USER",
      action: "DELETE_ACCOUNT",
      targetPath: `users/${uid}`,
      before: { uid: hashedUid },
      after: null,
      rawIp,
      metadata: {
        deletedSubcollectionsCount,
        anonymisedReportsCount,
        deletedResumesCount,
      },
    });
  } catch {
    // Non-fatal
  }

  // 8. Delete the Auth user last
  try {
    await admin.auth().deleteUser(uid);
  } catch (err: any) {
    if (err?.code !== "auth/user-not-found") {
      logError(FN, "Failed to delete auth user", { code: err?.code });
    }
  }

  logInfo(FN, "Account deletion completed", {
    uidHash: hashedUid,
    subcollectionsDeleted: deletedSubcollectionsCount,
    reportsAnonymised: anonymisedReportsCount,
  });

  return {
    success: true,
    deletedSubcollectionsCount,
    anonymisedReportsCount,
    deletedResumesCount,
  };
}

export const deleteAccount = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to delete account.");
    }

    validate(DeleteAccountInputSchema, request.data);

    // Require recent sign-in (auth_time within 5 minutes / 300 seconds)
    const authTime = request.auth.token.auth_time;
    const nowSeconds = Math.floor(Date.now() / 1000);

    if (!authTime || nowSeconds - authTime > 300) {
      throw new HttpsError(
        "failed-precondition",
        "REAUTH_REQUIRED"
      );
    }

    const uid = request.auth.uid;
    const rawIp = request.rawRequest.ip;

    const result = await executeAccountDeletion(uid, rawIp);
    return result;
  }
);
