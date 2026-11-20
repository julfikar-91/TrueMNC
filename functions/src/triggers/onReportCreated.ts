// functions/src/triggers/onReportCreated.ts
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

import { REGION, Collections, db, Roles } from "../utils/config";
import { writeAudit } from "../utils/audit";
import { logInfo, logWarn } from "../utils/logger";

const FN = "onReportCreated";

/**
 * Core business logic for processing a newly created report.
 * Separated for deterministic unit/integration testing without trigger harnesses.
 */
export async function handleReportCreated(
  reportId: string,
  reportData: Record<string, any>
): Promise<{ counted: boolean; thresholdReached: boolean; count: number }> {
  const jobId = reportData.jobId;
  const reporterUid = reportData.reporterUid;

  if (!jobId || !reporterUid) {
    return { counted: false, thresholdReached: false, count: 0 };
  }

  const jobRef = db().collection(Collections.JOBS).doc(jobId);
  const reporterRef = jobRef.collection("reporters").doc(reporterUid);

  let counted = false;
  let thresholdReached = false;
  let finalCount = 0;
  let beforeData: any = null;
  let newReasons: string[] = [];

  await db().runTransaction(async (t) => {
    // 1. Enforce distinct reporter counting: check if uid already exists in subcollection
    const reporterDoc = await t.get(reporterRef);
    if (reporterDoc.exists) {
      logInfo(FN, "Reporter already counted for job", { jobId, reporterUid });
      return;
    }

    const jobDoc = await t.get(jobRef);
    if (!jobDoc.exists) {
      logWarn(FN, "Target job not found for report", { jobId });
      return;
    }

    beforeData = jobDoc.data();
    finalCount = (beforeData?.reportCount || 0) + 1;
    counted = true;

    // Record reporter in subcollection (never exposed publicly)
    t.set(reporterRef, {
      reportedAt: admin.firestore.FieldValue.serverTimestamp(),
      reportId,
      category: reportData.category || "OTHER",
    });

    const updates: Record<string, any> = {
      reportCount: finalCount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // 2. Threshold check: >= 3 distinct reporters transitions job to PENDING_REVIEW
    if (finalCount >= 3) {
      thresholdReached = true;
      updates.status = "PENDING_REVIEW";
      const existingReasons = beforeData?.reviewReasons || [];
      newReasons = Array.from(new Set([...existingReasons, "USER_REPORTS"]));
      updates.reviewReasons = newReasons;
    }

    t.update(jobRef, updates);
  });

  // 3. Write immutable system audit entry when threshold is hit
  if (thresholdReached) {
    try {
      await writeAudit({
        actorUid: "system",
        role: Roles.SUPER_ADMIN,
        action: "FLAG_JOB_PENDING_REVIEW",
        targetPath: `jobs/${jobId}`,
        before: {
          status: beforeData?.status,
          reportCount: finalCount - 1,
        },
        after: {
          status: "PENDING_REVIEW",
          reportCount: finalCount,
          reviewReasons: newReasons,
        },
      });
      logInfo(FN, "Job reached report threshold (>= 3). Moved to PENDING_REVIEW.", {
        jobId,
        reportCount: finalCount,
      });
    } catch (err) {
      logWarn(FN, "Failed to write audit log for reported job", { err: (err as Error).message });
    }
  }

  return { counted, thresholdReached, count: finalCount };
}

export const onReportCreated = onDocumentCreated(
  {
    document: `${Collections.REPORTS}/{reportId}`,
    region: REGION,
  },
  async (event) => {
    const reportId = event.params.reportId;
    const reportData = event.data?.data();
    if (!reportData) return;

    await handleReportCreated(reportId, reportData);
  }
);
