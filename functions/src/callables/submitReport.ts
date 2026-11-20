// functions/src/callables/submitReport.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo } from "../utils/logger";

const FN = "submitReport";

export const REPORT_CATEGORIES = [
  "INCORRECT_JOB",
  "BROKEN_LINK",
  "SUSPICIOUS_JOB",
  "APP_ISSUE",
  "OTHER",
] as const;

export const SubmitReportInputSchema = z.object({
  category: z.enum(REPORT_CATEGORIES),
  jobId: z.string().min(1).optional(),
  text: z.string().min(5, "Text must be at least 5 characters").max(1000, "Text cannot exceed 1000 characters"),
  screenshotPath: z.string().optional(),
});

export async function checkAndIncrementReportRateLimit(uid: string): Promise<boolean> {
  const today = new Date().toISOString().split("T")[0];
  const usageRef = db()
    .collection("users")
    .doc(uid)
    .collection("aiUsage")
    .doc(`reports_${today}`);

  let allowed = false;
  await db().runTransaction(async (t) => {
    const snap = await t.get(usageRef);
    const current = snap.exists ? (snap.data()?.count || 0) : 0;
    if (current >= 10) {
      allowed = false;
      return;
    }
    t.set(usageRef, { count: current + 1, updatedAt: new Date() }, { merge: true });
    allowed = true;
  });
  return allowed;
}

export const submitReport = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to submit a report.");
    }

    const uid = request.auth.uid;
    const data = validate(SubmitReportInputSchema, request.data);

    // 1. Validate Screenshot Path
    if (data.screenshotPath) {
      const allowedPrefix = `reports/${uid}/`;
      if (!data.screenshotPath.startsWith(allowedPrefix) || data.screenshotPath.includes("..")) {
        throw new HttpsError(
          "invalid-argument",
          `Screenshot path must be under reports/{uid}/. Provided: ${data.screenshotPath}`
        );
      }
    }

    // 2. Validate Job Exists if provided
    if (data.jobId) {
      const jobSnap = await db().collection(Collections.JOBS).doc(data.jobId).get();
      if (!jobSnap.exists) {
        throw new HttpsError("not-found", `Job ${data.jobId} does not exist.`);
      }
    }

    // 3. Rate Limit: 10 per day per uid
    const allowed = await checkAndIncrementReportRateLimit(uid);
    if (!allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily report limit reached (max 10 reports per day)."
      );
    }

    // 4. Create reports/{id} document with status OPEN
    const reportRef = db().collection(Collections.REPORTS).doc();
    const newReport = {
      id: reportRef.id,
      reporterUid: uid,
      category: data.category,
      jobId: data.jobId || null,
      text: data.text.trim(),
      screenshotPath: data.screenshotPath || null,
      status: "OPEN",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await reportRef.set(newReport);
    logInfo(FN, "Report created successfully", { reportId: reportRef.id, category: data.category });

    return {
      success: true,
      reportId: reportRef.id,
    };
  }
);
