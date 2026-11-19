// functions/src/callables/deleteResume.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, storage, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo, logWarn } from "../utils/logger";

const FN = "deleteResume";

const DeleteResumeInputSchema = z.object({
  resumeId: z.string().min(1, "resumeId is required"),
});

export const deleteResume = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to delete resume.");
    }

    const { uid } = request.auth;
    const input = validate(DeleteResumeInputSchema, request.data);
    const { resumeId } = input;

    logInfo(FN, "Deleting resume", { resumeId, uid });

    const resumeRef = db().collection(Collections.RESUMES).doc(resumeId);
    const resumeSnap = await resumeRef.get();

    if (!resumeSnap.exists) {
      throw new HttpsError("not-found", "Resume record not found.");
    }

    const resumeData = resumeSnap.data();
    if (resumeData?.uid !== uid) {
      throw new HttpsError("permission-denied", "Unauthorized: Resume belongs to another user.");
    }

    // 1. Delete file from Storage if storagePath exists
    const storagePath = resumeData.storagePath;
    if (storagePath) {
      try {
        const bucket = storage().bucket();
        await bucket.file(storagePath).delete({ ignoreNotFound: true });
        logInfo(FN, "Deleted resume file from storage", { resumeId });
      } catch (err) {
        logWarn(FN, "Failed to delete storage file (continuing)", {
          resumeId,
          err: (err as Error).message,
        });
      }
    }

    // 2. Delete or mark draft in resumeParses
    try {
      const parseRef = db().collection("resumeParses").doc(resumeId);
      await parseRef.update({
        status: "DELETED",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch {
      // Non-fatal if resumeParses document didn't exist
    }

    // 3. Update resume record status to DELETED (confirmed profile in users/{uid} remains)
    await resumeRef.update({
      status: "DELETED",
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logInfo(FN, "Resume marked as DELETED", { resumeId, uid });

    return {
      success: true,
      resumeId,
      status: "DELETED",
    };
  }
);
