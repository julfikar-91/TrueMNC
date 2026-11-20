// functions/src/callables/refreshRecommendations.ts
// User-initiated recommendations refresh with 5-minute rate limit.
// NO Gemini calls permitted here — deterministic scoring only.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { REGION, db, Collections } from "../utils/config";
import { logInfo, logWarn } from "../utils/logger";
import { onProfileConfirmedOrPreferencesChanged } from "../matching/fanout";

const FN = "refreshRecommendations";
const RATE_LIMIT_MS = 5 * 60 * 1000; // 5 minutes

export const refreshRecommendations = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to refresh recommendations.");
    }

    const { uid } = request.auth;
    logInfo(FN, "User requested recommendations refresh", { uid });

    const userRef = db().collection(Collections.USERS).doc(uid);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User document not found.");
    }

    const userData = userSnap.data() || {};
    const lastRefreshTimestamp = userData.lastManualRecommendationsRefresh?.toMillis?.() || 0;
    const now = Date.now();

    // Check rate limit: at most 1 per 5 minutes per UID
    if (now - lastRefreshTimestamp < RATE_LIMIT_MS) {
      const waitSeconds = Math.ceil((RATE_LIMIT_MS - (now - lastRefreshTimestamp)) / 1000);
      logWarn(FN, "Rate limit hit for recommendations refresh", { uid, waitSeconds });
      return {
        status: "RATE_LIMITED",
        message: `You can only refresh recommendations once every 5 minutes. Try again in ${waitSeconds}s.`,
        retryAfterSeconds: waitSeconds,
      };
    }

    // Update last refresh timestamp immediately
    await userRef.update({
      lastManualRecommendationsRefresh: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Run recommendation refresh pipeline
    const refreshResult = await onProfileConfirmedOrPreferencesChanged(uid, true);

    return {
      status: "SUCCESS",
      recommendationsCount: refreshResult.recommendationsCount,
      scoredCount: refreshResult.scoredCount,
    };
  },
);
