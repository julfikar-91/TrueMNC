// functions/src/matching/fanout.ts
// Fanout matching engine, recommendation pipeline, and lifecycle triggers.
// NO Gemini calls permitted here — deterministic scoring only.

import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import { REGION, db, Collections } from "../utils/config";
import { logInfo, logWarn } from "../utils/logger";
import {
  scoreForUser,
  checkStage1Eligibility,
  CandidateProfile,
  CareerPreferences,
  JobMatchCriteria,
  ScoringConfig,
  CandidateEducation,
  CandidateExperienceItem,
} from "./score";

const FN = "fanout";

// ── Default Config Helper ─────────────────────────────────────────────────────
export async function getActiveScoringConfig(): Promise<ScoringConfig> {
  try {
    const snap = await db().collection("config").doc("scoring_v1").get();
    if (snap.exists) {
      return snap.data() as ScoringConfig;
    }
  } catch (err) {
    logWarn(FN, "Failed to read config/scoring_v1, using default scoring v1", {
      err: (err as Error).message,
    });
  }
  return {
    version: "v1",
    weights: {
      skills: 40,
      education: 15,
      experience: 15,
      location: 10,
      preference: 20,
    },
    threshold: 55,
    softCapCoverage: 0.5,
    softCap: 74,
    labelCutoffs: {
      excellent: 80,
      good: 65,
      fair: 55,
    },
  };
}

// ── User Profile Loader ───────────────────────────────────────────────────────
export async function loadUserCandidateData(uid: string): Promise<{
  profile: CandidateProfile | null;
  prefs: CareerPreferences | null;
  matchKeys: string[];
  profileConfirmed: boolean;
}> {
  const userRef = db().collection(Collections.USERS).doc(uid);
  const [userSnap, skillsSnap, eduSnap, expSnap] = await Promise.all([
    userRef.get(),
    userRef.collection("skills").doc("canonical").get(),
    userRef.collection("education").where("confirmed", "==", true).get(),
    userRef.collection("experience").where("confirmed", "==", true).get(),
  ]);

  if (!userSnap.exists) {
    return { profile: null, prefs: null, matchKeys: [], profileConfirmed: false };
  }

  const userData = userSnap.data() || {};
  const isProfileConfirmed = userData.profile_confirmed === true;

  const canonicalSkills: string[] = skillsSnap.exists
    ? skillsSnap.data()?.canonicalList || []
    : [];

  const education: CandidateEducation[] = eduSnap.docs.map((d) => {
    const data = d.data();
    return {
      degree: data.degree,
      level: data.level,
      specialization: data.specialization,
      field: data.field,
      institution: data.institution,
      confirmed: data.confirmed,
      provenance: data.provenance,
    };
  });

  const experienceItems: CandidateExperienceItem[] = expSnap.docs.map((d) => {
    const data = d.data();
    return {
      title: data.title,
      company: data.company,
      startDate: data.startDate,
      endDate: data.endDate,
      months: data.months,
      confirmed: data.confirmed,
      provenance: data.provenance,
    };
  });

  const profile: CandidateProfile = {
    id: uid,
    name: userData.name,
    location: userData.location,
    state: userData.state,
    skills: canonicalSkills,
    canonicalSkills,
    education,
    experience: experienceItems,
    confirmedMonths: userData.confirmedMonths ?? null,
    isFresher: userData.isFresher ?? false,
    profile_confirmed: isProfileConfirmed,
  };

  const prefs: CareerPreferences | null = userData.preferences || null;
  const matchKeys: string[] = Array.isArray(userData.matchKeys)
    ? userData.matchKeys
    : [];

  return { profile, prefs, matchKeys, profileConfirmed: isProfileConfirmed };
}

// ── 1. onJobActivated ─────────────────────────────────────────────────────────
// tags = matchTags; chunk by 30 for array-contains-any on users.matchKeys with profile_confirmed == true;
// paginate; enqueue matchBatch(jobId, uids[200]) to the match queue.
export async function onJobActivated(
  job: Partial<JobMatchCriteria>,
): Promise<{ totalMatchedUsers: number; batchesEnqueued: number }> {
  if (!job.id) return { totalMatchedUsers: 0, batchesEnqueued: 0 };
  const jobId = job.id;

  const matchTags: string[] = Array.isArray(job.locations)
    ? [...(job as any).matchTags || []]
    : (job as any).matchTags || [];

  if (matchTags.length === 0) {
    logInfo(FN, `Job ${jobId} has no matchTags; skipping activation fanout.`);
    return { totalMatchedUsers: 0, batchesEnqueued: 0 };
  }

  logInfo(FN, `Starting fanout for activated job ${jobId}`, {
    matchTagsCount: matchTags.length,
  });

  // Chunk tags by 30 (Firestore array-contains-any limit)
  const tagChunks: string[][] = [];
  for (let i = 0; i < matchTags.length; i += 30) {
    tagChunks.push(matchTags.slice(i, i + 30));
  }

  const matchedUids = new Set<string>();

  for (const chunk of tagChunks) {
    const usersSnap = await db()
      .collection(Collections.USERS)
      .where("profile_confirmed", "==", true)
      .where("matchKeys", "array-contains-any", chunk)
      .get();

    for (const doc of usersSnap.docs) {
      matchedUids.add(doc.id);
    }
  }

  const uids = Array.from(matchedUids);
  logInfo(FN, `Found ${uids.length} confirmed users matching job ${jobId}`);

  // Enqueue matchBatch in chunks of 200
  let batchesEnqueued = 0;
  for (let i = 0; i < uids.length; i += 200) {
    const batch = uids.slice(i, i + 200);
    await matchBatch(jobId, batch);
    batchesEnqueued++;
  }

  return { totalMatchedUsers: uids.length, batchesEnqueued };
}

// ── 2. matchBatch ─────────────────────────────────────────────────────────────
// skip if already scored for (uid, contentHash, scoreVersion); score;
// if score >= threshold upsert users/{uid}/recommendations/{jobId} (server only) with breakdown, reasons, isNew;
// notification hook is a stub (log only; Day 10).
export async function matchBatch(
  jobId: string,
  uids: string[],
): Promise<{ scored: number; upserted: number; skipped: number }> {
  const jobSnap = await db().collection(Collections.JOBS).doc(jobId).get();
  if (!jobSnap.exists) {
    logWarn(FN, `Job ${jobId} not found during matchBatch`);
    return { scored: 0, upserted: 0, skipped: 0 };
  }

  const job = { id: jobSnap.id, ...jobSnap.data() } as JobMatchCriteria;
  const config = await getActiveScoringConfig();
  const threshold = config.threshold ?? 55;

  let scoredCount = 0;
  let upsertedCount = 0;
  let skippedCount = 0;

  for (const uid of uids) {
    const recRef = db()
      .collection(Collections.USERS)
      .doc(uid)
      .collection("recommendations")
      .doc(jobId);

    const recSnap = await recRef.get();
    if (recSnap.exists) {
      const existing = recSnap.data();
      // Skip if already scored for (uid, contentHash, scoreVersion)
      if (
        existing?.contentHash === job.contentHash &&
        existing?.scoreVersion === config.version
      ) {
        skippedCount++;
        continue;
      }
    }

    const { profile, prefs, profileConfirmed } = await loadUserCandidateData(uid);
    if (!profileConfirmed || !profile) {
      continue;
    }

    const result = scoreForUser(profile, prefs, job, config);
    scoredCount++;

    if (result.score >= threshold) {
      const isNew = !recSnap.exists;
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
          isNew,
          createdAt: recSnap.exists
            ? recSnap.data()?.createdAt || admin.firestore.FieldValue.serverTimestamp()
            : admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      upsertedCount++;

      // Day 10 Notification hook stub (log only)
      logInfo(
        FN,
        `[NOTIFICATION-STUB] Recommendation created for user ${uid} on job ${jobId} with score ${result.score}`,
      );
    }
  }

  return { scored: scoredCount, upserted: upsertedCount, skipped: skippedCount };
}

// ── 3. onProfileConfirmedOrPreferencesChanged ─────────────────────────────────
// Debounced 60 s; candidates = ACTIVE jobs matching the user's matchKeys (limit 500, newest first);
// score all; replace the recommendation set; mark isNew only for jobs not seen before;
// cap top 200 per user.
export async function onProfileConfirmedOrPreferencesChanged(
  uid: string,
  bypassDebounce = false,
): Promise<{ scoredCount: number; recommendationsCount: number }> {
  const userRef = db().collection(Collections.USERS).doc(uid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    return { scoredCount: 0, recommendationsCount: 0 };
  }

  const userData = userSnap.data() || {};
  if (userData.profile_confirmed !== true) {
    logInfo(FN, `User ${uid} profile not confirmed; skipping recommendation refresh.`);
    return { scoredCount: 0, recommendationsCount: 0 };
  }

  // Debounce check (60 seconds)
  const now = Date.now();
  const lastRefresh = userData.lastMatchingRefresh?.toMillis?.() || 0;
  if (!bypassDebounce && now - lastRefresh < 60 * 1000) {
    logInfo(FN, `Debounce active for user ${uid}: last matching ran ${Math.round((now - lastRefresh) / 1000)}s ago.`);
    return { scoredCount: 0, recommendationsCount: 0 };
  }

  // Update last refresh timestamp
  await userRef.update({
    lastMatchingRefresh: admin.firestore.FieldValue.serverTimestamp(),
  });

  const { profile, prefs, matchKeys } = await loadUserCandidateData(uid);
  if (!profile || matchKeys.length === 0) {
    return { scoredCount: 0, recommendationsCount: 0 };
  }

  // Query ACTIVE jobs matching user's matchKeys (chunk by 30, limit 500)
  const tagChunks: string[][] = [];
  for (let i = 0; i < matchKeys.length; i += 30) {
    tagChunks.push(matchKeys.slice(i, i + 30));
  }

  const candidateMap = new Map<string, JobMatchCriteria>();

  for (const chunk of tagChunks) {
    const jobsSnap = await db()
      .collection(Collections.JOBS)
      .where("status", "==", "ACTIVE")
      .where("matchTags", "array-contains-any", chunk)
      .orderBy("postedAt", "desc")
      .limit(500)
      .get();

    for (const doc of jobsSnap.docs) {
      if (!candidateMap.has(doc.id)) {
        candidateMap.set(doc.id, { id: doc.id, ...doc.data() } as JobMatchCriteria);
        if (candidateMap.size >= 500) break;
      }
    }
    if (candidateMap.size >= 500) break;
  }

  const config = await getActiveScoringConfig();
  const threshold = config.threshold ?? 55;

  // Score all candidates
  const scoredItems: Array<{
    job: JobMatchCriteria;
    score: number;
    result: ReturnType<typeof scoreForUser>;
  }> = [];

  for (const job of candidateMap.values()) {
    const eligibility = checkStage1Eligibility(job);
    if (!eligibility.eligible) continue;

    const result = scoreForUser(profile, prefs, job, config);
    if (result.score >= threshold) {
      scoredItems.push({ job, score: result.score, result });
    }
  }

  // Sort by score DESC, cap top 200 per user
  scoredItems.sort((a, b) => b.score - a.score);
  const top200 = scoredItems.slice(0, 200);

  // Fetch existing recommendations to track isNew
  const recsCol = userRef.collection("recommendations");
  const existingRecsSnap = await recsCol.get();
  const existingRecIds = new Set(existingRecsSnap.docs.map((d) => d.id));
  const newTop200Ids = new Set(top200.map((item) => item.job.id));

  // Batch writes & deletions
  const batch = db().batch();

  // 1. Upsert top 200
  for (const item of top200) {
    const recRef = recsCol.doc(item.job.id);
    const isNew = !existingRecIds.has(item.job.id);
    batch.set(
      recRef,
      {
        jobId: item.job.id,
        score: item.result.score,
        label: item.result.label,
        breakdown: item.result.breakdown,
        reasons: item.result.reasons,
        gaps: item.result.gaps,
        matchedSkills: item.result.matchedSkills,
        missingSkills: item.result.missingSkills,
        niceToHave: item.result.niceToHave,
        flags: item.result.flags,
        scoreVersion: item.result.scoreVersion,
        contentHash: item.job.contentHash || null,
        isNew,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: isNew
          ? admin.firestore.FieldValue.serverTimestamp()
          : (existingRecsSnap.docs.find((d) => d.id === item.job.id)?.data()?.createdAt ||
            admin.firestore.FieldValue.serverTimestamp()),
      },
      { merge: true },
    );
  }

  // 2. Remove recommendations not in top 200
  for (const doc of existingRecsSnap.docs) {
    if (!newTop200Ids.has(doc.id)) {
      batch.delete(doc.ref);
    }
  }

  await batch.commit();

  logInfo(FN, `Refreshed recommendations for user ${uid}: ${top200.length} stored`);
  return { scoredCount: candidateMap.size, recommendationsCount: top200.length };
}

// ── 4. onJobStatusChange ──────────────────────────────────────────────────────
// When a job becomes CLOSED/EXPIRED/REJECTED/DUPLICATE remove it from recommendations
// (batched, via collection group query on jobId); when job content changes re-score.
export async function onJobStatusChange(
  jobId: string,
  beforeStatus: string | undefined,
  afterStatus: string | undefined,
  beforeHash?: string | null,
  afterHash?: string | null,
  jobData?: Partial<JobMatchCriteria>,
): Promise<{ deletedRecommendations: number; rescoreTriggered: boolean }> {
  let deletedCount = 0;
  let rescoreTriggered = false;

  const terminalStatuses = ["CLOSED", "EXPIRED", "REJECTED", "DUPLICATE"];

  if (afterStatus && terminalStatuses.includes(afterStatus)) {
    logInfo(FN, `Job ${jobId} became ${afterStatus}. Removing from all recommendations.`);

    const recsSnap = await db()
      .collectionGroup("recommendations")
      .where("jobId", "==", jobId)
      .get();

    if (!recsSnap.empty) {
      // Batch delete in chunks of 500
      const docs = recsSnap.docs;
      for (let i = 0; i < docs.length; i += 500) {
        const batch = db().batch();
        for (const doc of docs.slice(i, i + 500)) {
          batch.delete(doc.ref);
        }
        await batch.commit();
      }
      deletedCount = docs.length;
      logInfo(FN, `Removed ${deletedCount} recommendations for job ${jobId}`);
    }
  } else if (
    afterStatus === "ACTIVE" &&
    (beforeStatus !== "ACTIVE" || (beforeHash && afterHash && beforeHash !== afterHash))
  ) {
    // Job became ACTIVE or content changed while ACTIVE -> Re-score
    logInfo(FN, `Job ${jobId} content changed or became ACTIVE. Re-scoring fanout.`);
    if (jobData) {
      await onJobActivated(jobData);
      rescoreTriggered = true;
    }
  }

  return { deletedRecommendations: deletedCount, rescoreTriggered };
}

// ── 5. pruneRecommendations (Daily Scheduler) ─────────────────────────────────
// Keep top 200 per user, drop lowest.
export async function executePruneRecommendations(): Promise<{
  usersProcessed: number;
  prunedRecommendations: number;
}> {
  logInfo(FN, "Running daily recommendation pruning schedule");
  let usersProcessed = 0;
  let prunedCount = 0;

  const usersSnap = await db()
    .collection(Collections.USERS)
    .where("profile_confirmed", "==", true)
    .get();

  for (const userDoc of usersSnap.docs) {
    const recsSnap = await userDoc.ref
      .collection("recommendations")
      .orderBy("score", "desc")
      .get();

    if (recsSnap.size > 200) {
      usersProcessed++;
      const docsToDelete = recsSnap.docs.slice(200);
      const batch = db().batch();
      for (const d of docsToDelete) {
        batch.delete(d.ref);
      }
      await batch.commit();
      prunedCount += docsToDelete.length;
    }
  }

  logInfo(FN, `Pruning complete. Processed ${usersProcessed} users, dropped ${prunedCount} recommendations.`);
  return { usersProcessed, prunedRecommendations: prunedCount };
}

export const pruneRecommendations = onSchedule(
  {
    schedule: "0 3 * * *",
    region: REGION,
    timeZone: "Asia/Kolkata",
  },
  async () => {
    await executePruneRecommendations();
  },
);

// ── Firestore Trigger: onJobWriteTrigger ──────────────────────────────────────
export const onJobWriteTrigger = onDocumentWritten(
  { document: `${Collections.JOBS}/{jobId}`, region: REGION },
  async (event) => {
    const jobId = event.params.jobId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!afterData) {
      // Document deleted -> remove recommendations
      await onJobStatusChange(jobId, beforeData?.status, "CLOSED");
      return;
    }

    const beforeStatus = beforeData?.status;
    const afterStatus = afterData.status;
    const beforeHash = beforeData?.contentHash;
    const afterHash = afterData.contentHash;

    await onJobStatusChange(
      jobId,
      beforeStatus,
      afterStatus,
      beforeHash,
      afterHash,
      { id: jobId, ...afterData } as JobMatchCriteria,
    );
  },
);

// ── Cloud Task Dispatcher Stub for matchBatch ─────────────────────────────────
export interface MatchBatchPayload {
  jobId: string;
  uids: string[];
}

export const matchBatchTask = onTaskDispatched<MatchBatchPayload>(
  {
    region: REGION,
    rateLimits: {
      maxConcurrentDispatches: 10,
    },
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 15,
      maxBackoffSeconds: 120,
    },
  },
  async (request) => {
    await matchBatch(request.data.jobId, request.data.uids);
  },
);
