// functions/src/callables/saveProfileSection.ts
// Updates candidate profile section and triggers debounced matching refresh.
// NO Gemini calls permitted here.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo } from "../utils/logger";
import { onProfileConfirmedOrPreferencesChanged } from "../matching/fanout";

const FN = "saveProfileSection";

export const SaveProfileSectionInputSchema = z.object({
  section: z.enum([
    "personal",
    "education",
    "skills",
    "experience",
    "projects",
    "certifications",
  ]),
  data: z.any(),
});

export const saveProfileSection = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to update profile.");
    }

    const { uid } = request.auth;
    const { section, data } = validate(SaveProfileSectionInputSchema, request.data);

    logInfo(FN, "Saving profile section", { uid, section });

    const userRef = db().collection(Collections.USERS).doc(uid);

    if (section === "personal") {
      await userRef.set(
        {
          ...data,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } else if (section === "skills") {
      const skillsDocRef = userRef.collection("skills").doc("canonical");
      await skillsDocRef.set(
        {
          canonicalList: Array.isArray(data) ? data : data?.canonicalList || [],
          confirmed: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } else {
      // Subcollections: education, experience, projects, certifications
      const items = Array.isArray(data) ? data : [data];
      const batch = db().batch();
      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const docId = item.id || `${section.slice(0, 3)}_${i}`;
        const itemRef = userRef.collection(section).doc(docId);
        batch.set(
          itemRef,
          {
            ...item,
            id: docId,
            confirmed: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      await batch.commit();
    }

    // Trigger debounced matching refresh
    try {
      await onProfileConfirmedOrPreferencesChanged(uid);
    } catch (err) {
      logInfo(FN, "Debounced refresh queued/handled", { err });
    }

    return { success: true, section };
  },
);
