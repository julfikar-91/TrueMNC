// functions/src/tasks/collectionPipeline.ts
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

import { REGION, db, Collections } from "../utils/config";
import { getAdapter } from "../adapters/registry";
import { RawJob, SourceDoc } from "../adapters/types";
import {
  runRules,
  computeDedupeKey,
  ruleR3UrlLive,
} from "../rules/verificationRules";
import { extractJobWithGemini } from "../ai/extractJob";
import { logInfo, logWarn, logError } from "../utils/logger";
import { onJobActivated } from "../matching/fanout";

const FN = "collectionPipeline";

export interface CollectSourceTaskPayload {
  sourceId: string;
}

export interface ProcessRawJobTaskPayload {
  sourceId: string;
  companyId: string;
  collectionRunId: string;
  rawJob: RawJob;
}

// ── Search Tokens & Match Tags Builders ──────────────────────────────────────
export function buildSearchTokens(
  terms: (string | null | undefined)[],
  maxTokens = 60,
): string[] {
  const tokenSet = new Set<string>();

  for (const term of terms) {
    if (!term) continue;
    const words = term
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, " ")
      .split(/\s+/)
      .filter((w) => w.length >= 2);

    for (const word of words) {
      tokenSet.add(word);
      for (let i = 2; i <= Math.min(word.length, 12); i++) {
        tokenSet.add(word.substring(0, i));
        if (tokenSet.size >= maxTokens) break;
      }
      if (tokenSet.size >= maxTokens) break;
    }
    if (tokenSet.size >= maxTokens) break;
  }

  return Array.from(tokenSet).slice(0, maxTokens);
}

export function buildMatchTags(params: {
  requiredSkills: string[];
  category?: string | null;
  city?: string | null;
  jobType?: string | null;
}): string[] {
  const tags = new Set<string>();

  for (const skill of params.requiredSkills) {
    if (skill.trim()) tags.add(`skill:${skill.toLowerCase().trim()}`);
  }
  if (params.category) {
    tags.add(`category:${params.category.toLowerCase().trim()}`);
  }
  if (params.city) {
    tags.add(`city:${params.city.toLowerCase().trim()}`);
  }
  if (params.jobType) {
    tags.add(`type:${params.jobType.toLowerCase().trim()}`);
  }

  return Array.from(tags);
}

// ── 1. Cloud Scheduler: dispatchCollection (Every 15 min) ───────────────────
export const dispatchCollection = onSchedule(
  {
    schedule: "every 15 minutes",
    region: REGION,
    timeZone: "Asia/Kolkata",
  },
  async () => {
    logInfo(FN, "dispatchCollection cron triggered");

    const now = new Date();
    const sourcesSnap = await db()
      .collection("sources")
      .where("enabled", "==", true)
      .get();

    logInfo(FN, `Found ${sourcesSnap.size} enabled sources to evaluate for collection`);

    for (const doc of sourcesSnap.docs) {
      const source = { id: doc.id, ...doc.data() } as SourceDoc;

      // 1. Check parent company verification
      const companyDoc = await db()
        .collection(Collections.COMPANIES)
        .doc(source.companyId)
        .get();

      if (!companyDoc.exists || companyDoc.data()?.isVerified !== true) {
        logInfo(FN, `Skipping source ${source.id}: company not verified`);
        continue;
      }

      // 2. Check nextRun schedule (default interval 6h, min 1h)
      const nextRunDate = source.nextRun ? source.nextRun.toDate() : null;
      if (nextRunDate && nextRunDate.getTime() > now.getTime()) {
        continue;
      }

      // 3. Dispatch collection task
      try {
        await executeCollectSource({ sourceId: source.id });
      } catch (err) {
        logError(FN, err, { sourceId: source.id });
      }
    }
  },
);

// ── 2. Cloud Task: collectSource (Concurrency 5, Idempotent) ─────────────────
export const collectSource = onTaskDispatched<CollectSourceTaskPayload>(
  {
    region: REGION,
    rateLimits: {
      maxConcurrentDispatches: 5,
    },
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 30,
      maxBackoffSeconds: 300,
    },
  },
  async (request) => {
    await executeCollectSource(request.data);
  },
);

export async function executeCollectSource(
  payload: CollectSourceTaskPayload,
): Promise<void> {
  const { sourceId } = payload;
  const sourceRef = db().collection("sources").doc(sourceId);
  const sourceSnap = await sourceRef.get();

  if (!sourceSnap.exists) {
    logWarn(FN, `Source ${sourceId} not found`);
    return;
  }

  const source = { id: sourceSnap.id, ...sourceSnap.data() } as SourceDoc;
  const companyRef = db().collection(Collections.COMPANIES).doc(source.companyId);
  const companySnap = await companyRef.get();
  if (!companySnap.exists) {
    logWarn(FN, `Company ${source.companyId} not found`);
    return;
  }

  // 1. Create collection run document
  const runRef = await db().collection("collectionRuns").add({
    sourceId: source.id,
    companyId: source.companyId,
    status: "RUNNING",
    jobsFound: 0,
    jobsCreated: 0,
    jobsUpdated: 0,
    errors: [],
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logInfo(FN, `Started collection run ${runRef.id} for source ${source.id}`);

  // 2. Call Adapter with safety guard
  let rawJobs: RawJob[] = [];
  try {
    const adapter = getAdapter(source.type);
    rawJobs = await adapter.fetchJobs(source);

    // Reset failure counter on success
    await sourceRef.update({
      consecutiveFailures: 0,
      lastRun: admin.firestore.FieldValue.serverTimestamp(),
      nextRun: new Date(Date.now() + (source.intervalMin || 360) * 60 * 1000),
    });
  } catch (err: unknown) {
    const errorMsg = (err as Error).message;
    logError(FN, err, { sourceId: source.id, runId: runRef.id });

    const failures = (source.consecutiveFailures || 0) + 1;
    const needsAttention = failures >= 3;

    await sourceRef.update({
      consecutiveFailures: failures,
      needsAttention,
      lastError: errorMsg,
      lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (needsAttention) {
      // Create admin alert / report
      await db().collection(Collections.REPORTS).add({
        type: "SOURCE_FAILURE_ALERT",
        targetId: source.id,
        targetType: "SOURCE",
        reason: `Source ${source.id} failed 3 consecutive times: ${errorMsg}`,
        status: "PENDING",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await runRef.update({
      status: "FAILED",
      errors: [errorMsg],
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // CRITICAL: Adapter failure NEVER closes jobs or marks them missing!
    return;
  }

  // 3. Process each RawJob
  const seenDedupeKeys = new Set<string>();
  let createdCount = 0;
  let updatedCount = 0;

  for (const rawJob of rawJobs) {
    const dedupeKey = computeDedupeKey({
      companyId: source.companyId,
      title: rawJob.title,
      city: rawJob.location,
      sourceJobId: rawJob.sourceJobId,
      applyUrl: rawJob.applyUrl,
    });
    seenDedupeKeys.add(dedupeKey);

    const contentHash = crypto
      .createHash("sha256")
      .update(`${rawJob.title}_${rawJob.description}_${rawJob.applyUrl}_${rawJob.location ?? ""}`)
      .digest("hex");

    const existingJobDoc = await db().collection(Collections.JOBS).doc(dedupeKey).get();

    if (existingJobDoc.exists) {
      const existingData = existingJobDoc.data()!;
      if (existingData.contentHash === contentHash) {
        // Unchanged: only touch lastSeenAt and reset missingCount
        await existingJobDoc.ref.update({
          lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
          missingCount: 0,
        });
        continue;
      }
      updatedCount++;
    } else {
      createdCount++;
    }

    // Process changed or new raw job
    await executeProcessRawJob({
      sourceId: source.id,
      companyId: source.companyId,
      collectionRunId: runRef.id,
      rawJob,
    });
  }

  // 4. Mark Missing Jobs
  // Query active jobs previously ingested from this source
  const existingJobsSnap = await db()
    .collection(Collections.JOBS)
    .where("sourceId", "==", source.id)
    .where("status", "in", ["ACTIVE", "PENDING_REVIEW"])
    .get();

  for (const jobDoc of existingJobsSnap.docs) {
    if (!seenDedupeKeys.has(jobDoc.id)) {
      const missingCount = ((jobDoc.data().missingCount as number) || 0) + 1;
      if (missingCount >= 2) {
        // Two consecutive misses -> CLOSE
        await jobDoc.ref.update({
          status: "CLOSED",
          closedAt: admin.firestore.FieldValue.serverTimestamp(),
          closedReason: "NOT_SEEN_IN_2_RUNS",
          missingCount,
        });
      } else {
        // Single miss: record missingCount=1 but remain ACTIVE
        await jobDoc.ref.update({
          missingCount,
        });
      }
    }
  }

  // 5. Finish Run Document
  await runRef.update({
    status: "COMPLETED",
    jobsFound: rawJobs.length,
    jobsCreated: createdCount,
    jobsUpdated: updatedCount,
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logInfo(FN, `Finished collection run ${runRef.id}`, {
    jobsFound: rawJobs.length,
    jobsCreated: createdCount,
    jobsUpdated: updatedCount,
  });
}

// ── 3. Cloud Task: processRawJob (Concurrency 20) ───────────────────────────
export const processRawJob = onTaskDispatched<ProcessRawJobTaskPayload>(
  {
    region: REGION,
    rateLimits: {
      maxConcurrentDispatches: 20,
    },
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 10,
    },
  },
  async (request) => {
    await executeProcessRawJob(request.data);
  },
);

export async function executeProcessRawJob(
  payload: ProcessRawJobTaskPayload,
): Promise<void> {
  const { sourceId, companyId, collectionRunId, rawJob } = payload;

  const companySnap = await db().collection(Collections.COMPANIES).doc(companyId).get();
  const companyData = companySnap.exists ? companySnap.data()! : {};
  const companyName = companyData.name || "Company";
  const companyLogo = companyData.logoUrl || null;
  const companyDomain = companyData.slug || companyData.website || "";

  const sourceSnap = await db().collection("sources").doc(sourceId).get();
  const sourceData = sourceSnap.exists ? sourceSnap.data()! : { enabled: true };

  const dedupeKey = computeDedupeKey({
    companyId,
    title: rawJob.title,
    city: rawJob.location,
    sourceJobId: rawJob.sourceJobId,
    applyUrl: rawJob.applyUrl,
  });

  // 1. AI Extraction (Cached)
  const extraction = await extractJobWithGemini(rawJob.description, {
    jobId: dedupeKey,
  });

  const aiData = extraction.data;
  const aiExtractionForRules = {
    confidence: aiData?.confidence ?? 0,
    isValidSchema: extraction.success && Boolean(aiData),
    category: aiData?.category,
  };

  // 2. Build Search Tokens & Match Tags
  const searchTokens = buildSearchTokens([
    rawJob.title,
    companyName,
    rawJob.location,
    aiData?.category,
    ...(aiData?.requiredSkills ?? []),
  ]);

  const matchTags = buildMatchTags({
    requiredSkills: aiData?.requiredSkills ?? [],
    category: aiData?.category,
    city: rawJob.location,
    jobType: aiData?.jobType,
  });

  // 3. Run Rules R1-R8
  const rulesResult = await runRules({
    source: {
      enabled: sourceData.enabled !== false,
      config: sourceData.config,
    },
    company: {
      id: companyId,
      domain: companyDomain,
      sourceVerified: companyData.isVerified === true,
    },
    job: {
      id: dedupeKey,
      title: rawJob.title,
      companyId,
      companyName,
      applyUrl: rawJob.applyUrl,
      description: rawJob.description,
      location: rawJob.location,
      city: rawJob.location,
      remote: rawJob.remote,
      sourceJobId: rawJob.sourceJobId,
      postedAt: rawJob.postedAt,
      firstSeenAt: new Date(),
      deadline: rawJob.deadline,
    },
    aiExtraction: aiExtractionForRules,
  });

  // 4. Determine Status & Verification
  let jobStatus: string;
  let verificationState: string;

  if (rawJob.deadline && rawJob.deadline.getTime() < Date.now()) {
    jobStatus = "EXPIRED";
    verificationState = "UNVERIFIED";
  } else if (rulesResult.allPass) {
    jobStatus = "ACTIVE";
    verificationState = "VERIFIED";
  } else {
    jobStatus = "PENDING_REVIEW";
    verificationState = "UNVERIFIED";
  }

  const contentHash = crypto
    .createHash("sha256")
    .update(`${rawJob.title}_${rawJob.description}_${rawJob.applyUrl}_${rawJob.location ?? ""}`)
    .digest("hex");

  // 5. Upsert Job Document
  const jobPayload = {
    id: dedupeKey,
    sourceId,
    companyId,
    companyName,
    companyLogo,
    sourceUrl: sourceData.url || null,
    applyUrl: rawJob.applyUrl,
    title: rawJob.title,
    description: rawJob.description,
    aiSummary: aiData?.summary || null,
    category: aiData?.category || "Software Development",
    jobType: aiData?.jobType || "TECHNICAL",
    requiredSkills: aiData?.requiredSkills || [],
    preferredSkills: aiData?.preferredSkills || [],
    minEdu: aiData?.minEdu || null,
    expMin: aiData?.expMin ?? null,
    expMax: aiData?.expMax ?? null,
    expLevel: aiData?.expLevel || "MID_LEVEL",
    employmentType: rawJob.employmentType || "PERMANENT",
    workMode: rawJob.remote ? "REMOTE" : "ONSITE",
    locations: rawJob.location ? [rawJob.location] : [],
    city: rawJob.location || null,
    deadline: rawJob.deadline ? admin.firestore.Timestamp.fromDate(rawJob.deadline) : null,
    postedAt: rawJob.postedAt
      ? admin.firestore.Timestamp.fromDate(rawJob.postedAt)
      : admin.firestore.FieldValue.serverTimestamp(),
    status: jobStatus,
    verification: {
      state: verificationState,
      checkedAt: admin.firestore.FieldValue.serverTimestamp(),
      rules: rulesResult.results.filter((r) => r.result === "PASS").map((r) => r.ruleCode),
    },
    reviewReasons: rulesResult.reasonCodes,
    searchTokens,
    matchTags,
    contentHash,
    missingCount: 0,
    lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const jobRef = db().collection(Collections.JOBS).doc(dedupeKey);
  await jobRef.set(jobPayload, { merge: true });

  // 6. Write validation results snapshot
  await jobRef.collection("validations").add({
    collectionRunId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    allPass: rulesResult.allPass,
    results: rulesResult.results,
    reasonCodes: rulesResult.reasonCodes,
  });

  logInfo(FN, `Processed job ${dedupeKey}: status=${jobStatus}, verification=${verificationState}`);
}

// ── 4. Cloud Scheduler: sweepExpired (Daily at 02:00) ────────────────────────
export const sweepExpired = onSchedule(
  {
    schedule: "0 2 * * *",
    region: REGION,
    timeZone: "Asia/Kolkata",
  },
  async () => {
    logInfo(FN, "sweepExpired cron triggered");
    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

    // 1. Mark expired jobs
    const activeJobsSnap = await db()
      .collection(Collections.JOBS)
      .where("status", "==", "ACTIVE")
      .get();

    for (const doc of activeJobsSnap.docs) {
      const data = doc.data();
      const deadline = data.deadline ? data.deadline.toDate() : null;

      if (deadline) {
        if (deadline.getTime() < now.getTime()) {
          // Deadline passed -> EXPIRED
          await doc.ref.update({
            status: "EXPIRED",
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        if (deadline.getTime() <= threeDaysFromNow.getTime()) {
          // Closing soon within 3 days
          await doc.ref.update({
            closingSoon: true,
          });
        }
      }
    }

    // 2. Sampled URL re-check for jobs older than 7 days
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const staleJobsSnap = await db()
      .collection(Collections.JOBS)
      .where("status", "==", "ACTIVE")
      .where("postedAt", "<=", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .limit(50)
      .get();

    for (const doc of staleJobsSnap.docs) {
      const data = doc.data();
      const applyUrl = data.applyUrl;
      if (!applyUrl) continue;

      const probeResult = await ruleR3UrlLive(applyUrl);
      if (probeResult.result !== "PASS") {
        const deadCount = ((data.deadUrlCount as number) || 0) + 1;
        if (deadCount >= 2) {
          await doc.ref.update({
            status: "CLOSED",
            closedReason: "URL_404_CONFIRMED",
            closedAt: admin.firestore.FieldValue.serverTimestamp(),
            deadUrlCount: deadCount,
          });
        } else {
          await doc.ref.update({ deadUrlCount: deadCount });
        }
      }
    }
  },
);

// ── 5. Firestore Trigger: onJobStatusChange ──────────────────────────────────
export const onJobStatusChange = onDocumentWritten(
  {
    document: "jobs/{jobId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    const previousStatus = beforeData?.status as string | undefined;
    const newStatus = afterData?.status as string | undefined;

    if (previousStatus === newStatus) {
      return; // No status transition
    }

    const companyId = afterData?.companyId || beforeData?.companyId;
    const category = afterData?.category || beforeData?.category;

    logInfo(FN, `Job status transition: ${previousStatus ?? "NEW"} -> ${newStatus ?? "DELETED"}`);

    // Update stats/global, company, and category activeCount in transaction
    await db().runTransaction(async (t) => {
      // 1. stats/global
      const statsRef = db().collection("stats").doc("global");
      const statsDoc = await t.get(statsRef);
      if (statsDoc.exists) {
        const updates: Record<string, unknown> = {};
        if (previousStatus) {
          updates[`jobs_${previousStatus}`] = admin.firestore.FieldValue.increment(-1);
        }
        if (newStatus) {
          updates[`jobs_${newStatus}`] = admin.firestore.FieldValue.increment(1);
        }
        t.update(statsRef, updates);
      }

      // 2. Company activeJobCount
      if (companyId) {
        const compRef = db().collection(Collections.COMPANIES).doc(companyId);
        const delta = (newStatus === "ACTIVE" ? 1 : 0) - (previousStatus === "ACTIVE" ? 1 : 0);
        if (delta !== 0) {
          t.update(compRef, {
            activeJobCount: admin.firestore.FieldValue.increment(delta),
          });
        }
      }

      // 3. Category activeCount
      if (category) {
        const catQuery = await db()
          .collection("categories")
          .where("name", "==", category)
          .limit(1)
          .get();
        if (!catQuery.empty) {
          const delta = (newStatus === "ACTIVE" ? 1 : 0) - (previousStatus === "ACTIVE" ? 1 : 0);
          if (delta !== 0) {
            t.update(catQuery.docs[0].ref, {
              activeCount: admin.firestore.FieldValue.increment(delta),
            });
          }
        }
      }
    });

    // 3. Match Fanout (when becoming ACTIVE)
    if (newStatus === "ACTIVE" && afterData) {
      logInfo(FN, `Job ${event.params.jobId} became ACTIVE. Dispatching match fanout.`);
      await onJobActivated({ id: event.params.jobId, ...afterData });
    }
  },
);
