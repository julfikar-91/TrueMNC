// functions/src/callables/saveCareerPreferences.ts
// Updates candidate career preferences and triggers debounced matching refresh.
// NO Gemini calls permitted here.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo } from "../utils/logger";
import { onProfileConfirmedOrPreferencesChanged } from "../matching/fanout";

const FN = "saveCareerPreferences";

export const SaveCareerPreferencesInputSchema = z.object({
  preferences: z.object({
    preferredTitles: z.array(z.string()).optional(),
    title: z.string().optional(),
    preferredCategories: z.array(z.string()).optional(),
    category: z.string().optional(),
    preferredJobTypes: z.array(z.string()).optional(),
    jobType: z.string().optional(),
    preferredEmploymentTypes: z.array(z.string()).optional(),
    employmentType: z.string().optional(),
    preferredWorkModes: z.array(z.string()).optional(),
    workMode: z.string().optional(),
    preferredCities: z.array(z.string()).optional(),
    city: z.string().optional(),
    openToRelocate: z.boolean().optional(),
    minSalary: z.number().optional(),
  }),
});

export const saveCareerPreferences = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to update career preferences.");
    }

    const { uid } = request.auth;
    const { preferences } = validate(SaveCareerPreferencesInputSchema, request.data);

    logInfo(FN, "Saving career preferences", { uid });

    const userRef = db().collection(Collections.USERS).doc(uid);
    await userRef.set(
      {
        preferences,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    // Trigger debounced matching refresh
    try {
      await onProfileConfirmedOrPreferencesChanged(uid);
    } catch (err) {
      logInfo(FN, "Debounced refresh queued/handled", { err });
    }

    return { success: true };
  },
);
