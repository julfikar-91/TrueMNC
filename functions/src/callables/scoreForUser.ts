// functions/src/callables/scoreForUser.ts
// On-demand job match scoring callable with recommendation cache fallback.
// NO Gemini calls permitted here — deterministic scoring only.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo } from "../utils/logger";
import {
  scoreForUser as computeScore,
  checkStage1Eligibility,
  JobMatchCriteria,
} from "../matching/score";
import {
  loadUserCandidateData,
  getActiveScoringConfig,
} from "../matching/fanout";

const FN = "scoreForUser";

export const ScoreForUserInputSchema = z.object({
  jobId: z.string().min(1, "jobId is required"),
});

export const scoreForUser = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to score a job.");
    }

    const { uid } = request.auth;
    const { jobId } = validate(ScoreForUserInputSchema, request.data);

    logInfo(FN, "Scoring job for user", { uid, jobId });

    // 1. Cache fallback: check existing recommendations
    const recRef = db()
      .collection(Collections.USERS)
      .doc(uid)
      .collection("recommendations")
      .doc(jobId);

    const recSnap = await recRef.get();
    if (recSnap.exists) {
      logInfo(FN, "Returning cached recommendation", { uid, jobId });
      return { cached: true, ...recSnap.data() };
    }

    // 2. Fetch job document
    const jobSnap = await db().collection(Collections.JOBS).doc(jobId).get();
    if (!jobSnap.exists) {
      throw new HttpsError("not-found", `Job ${jobId} not found.`);
    }

    const job = { id: jobSnap.id, ...jobSnap.data() } as JobMatchCriteria;

    // Check Stage 1 Hard Eligibility
    const eligibility = checkStage1Eligibility(job);
    if (!eligibility.eligible) {
      return {
        cached: false,
        score: 0,
        label: "Hidden",
        ineligibleReason: eligibility.reason,
      };
    }

    // 3. Load user candidate data & scoring config
    const [userData, config] = await Promise.all([
      loadUserCandidateData(uid),
      getActiveScoringConfig(),
    ]);

    const result = computeScore(userData.profile, userData.prefs, job, config);

    // If score >= threshold, save to recommendations
    const threshold = config.threshold ?? 55;
    if (result.score >= threshold) {
      await recRef.set(
        {
          jobId,
          score: result.score,
          label: result.label,
          breakdown: result.breakdown,
          reasons: result.reasons,
          gaps: result.gaps,
          matchedSkills: result.matchedSkills,
          missingSkills: result.missingSkills,
          niceToHave: result.niceToHave,
          flags: result.flags,
          scoreVersion: result.scoreVersion,
          contentHash: job.contentHash || null,
          isNew: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    return { cached: false, ...result };
  },
);
