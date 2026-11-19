// functions/src/callables/scoreApplication.ts
// Callable: scoreApplication — Gemini-powered resume/job match scoring.
// AI NEVER sets verification status. Score is informational only.
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo, logError } from "../utils/logger";

const FN = "scoreApplication";

const ScoreSchema = z.object({
  applicationId: z.string().min(1),
});

export const scoreApplication = onCall(
  {
    region: REGION,
    enforceAppCheck: true, // Enforce App Check
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const { applicationId } = validate(ScoreSchema, request.data);
    logInfo(FN, "Scoring application", { actorUid: request.auth.uid, applicationId });

    try {
      const appSnap = await db().collection(Collections.APPLICATIONS).doc(applicationId).get();
      if (!appSnap.exists) {
        throw new HttpsError("not-found", "Application not found.");
      }

      const appData = appSnap.data()!;

      // Guard: only the applicant or admin can trigger scoring
      if (
        appData.userId !== request.auth.uid &&
        !["ADMIN", "SUPER_ADMIN"].includes(request.auth.token["role"] as string)
      ) {
        throw new HttpsError("permission-denied", "Not authorised.");
      }

      // Placeholder until Gemini adapter is fully configured
      const score = 0.0;

      // Write score server-side only
      await db()
        .collection(Collections.APPLICATIONS)
        .doc(applicationId)
        .update({ matchScore: score, scoredAt: new Date() });

      return { score };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logError(FN, err, { actorUid: request.auth.uid, applicationId });
      throw new HttpsError("internal", "Scoring failed.");
    }
  },
);
