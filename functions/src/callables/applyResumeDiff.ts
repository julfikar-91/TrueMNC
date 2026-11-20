// functions/src/callables/applyResumeDiff.ts
// Applies confirmed resume diff updates to candidate profile and triggers debounced matching refresh.
// NO Gemini calls permitted here.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo } from "../utils/logger";
import { onProfileConfirmedOrPreferencesChanged } from "../matching/fanout";

const FN = "applyResumeDiff";

export const ApplyResumeDiffInputSchema = z.object({
  resumeId: z.string().min(1, "resumeId is required"),
  diffs: z.array(
    z.object({
      path: z.string(),
      action: z.enum(["ADD", "UPDATE", "REMOVE"]),
      value: z.any().optional(),
    }),
  ),
});

export const applyResumeDiff = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to apply resume diff.");
    }

    const { uid } = request.auth;
    const { resumeId, diffs } = validate(ApplyResumeDiffInputSchema, request.data);

    logInfo(FN, "Applying resume diff", { uid, resumeId, diffCount: diffs.length });

    const userRef = db().collection(Collections.USERS).doc(uid);
    const batch = db().batch();

    // Apply simple field updates to user document
    const userUpdates: Record<string, any> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    for (const diff of diffs) {
      if (diff.action === "UPDATE" || diff.action === "ADD") {
        userUpdates[diff.path] = diff.value;
      } else if (diff.action === "REMOVE") {
        userUpdates[diff.path] = admin.firestore.FieldValue.delete();
      }
    }

    batch.update(userRef, userUpdates);
    await batch.commit();

    // Trigger debounced matching refresh
    try {
      await onProfileConfirmedOrPreferencesChanged(uid);
    } catch (err) {
      logInfo(FN, "Debounced refresh queued/handled", { err });
    }

    return { success: true, appliedCount: diffs.length };
  },
);
