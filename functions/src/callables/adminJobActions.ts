// functions/src/callables/adminJobActions.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections, Roles } from "../utils/config";
import { requireRole } from "../utils/auth";
import { writeAudit } from "../utils/audit";
import { validate } from "../utils/validators";
import { runRules } from "../rules/verificationRules";
import { extractJobWithGemini, hashDescription } from "../ai/extractJob";

// ── 1. adminApproveJob ───────────────────────────────────────────────────────
const ApproveJobSchema = z.object({
  jobId: z.string(),
  note: z.string().optional(),
});

export const adminApproveJob = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(ApproveJobSchema, request.data);

    const jobRef = db().collection(Collections.JOBS).doc(data.jobId);
    const snap = await jobRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Job not found.");
    const before = snap.data();

    const updates = {
      status: "ACTIVE",
      "verification.state": "VERIFIED",
      "verification.checkedAt": admin.firestore.FieldValue.serverTimestamp(),
      "verification.approverUid": actorUid,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewClaim: null, // Clear soft lock
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await jobRef.update(updates);

    await writeAudit({
      actorUid,
      role: actorRole,
      action: "APPROVE_JOB",
      targetPath: `jobs/${data.jobId}`,
      before,
      after: updates,
      rawIp: request.rawRequest.ip,
      metadata: { note: data.note },
    });

    return { success: true, jobId: data.jobId, status: "ACTIVE" };
  },
);

// ── 2. adminRejectJob ────────────────────────────────────────────────────────
const RejectJobSchema = z.object({
  jobId: z.string(),
  reason: z.string().min(3, "Rejection reason is required"),
});

export const adminRejectJob = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(RejectJobSchema, request.data);

    const jobRef = db().collection(Collections.JOBS).doc(data.jobId);
    const snap = await jobRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Job not found.");
    const before = snap.data();

    const updates = {
      status: "REJECTED",
      "verification.state": "REJECTED",
      rejectionReason: data.reason,
      rejectedBy: actorUid,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewClaim: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await jobRef.update(updates);

    await writeAudit({
      actorUid,
      role: actorRole,
      action: "REJECT_JOB",
      targetPath: `jobs/${data.jobId}`,
      before,
      after: updates,
      rawIp: request.rawRequest.ip,
      metadata: { reason: data.reason },
    });

    return { success: true, jobId: data.jobId, status: "REJECTED" };
  },
);

// ── 3. adminRequestChanges ───────────────────────────────────────────────────
const RequestChangesSchema = z.object({
  jobId: z.string(),
  adminNote: z.string().min(3, "Admin note is required"),
});

export const adminRequestChanges = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(RequestChangesSchema, request.data);

    const jobRef = db().collection(Collections.JOBS).doc(data.jobId);
    const snap = await jobRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Job not found.");
    const before = snap.data();

    const updates = {
      status: "PENDING_REVIEW",
      adminReviewNote: data.adminNote,
      requestedChangesAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewClaim: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await jobRef.update(updates);

    await writeAudit({
      actorUid,
      role: actorRole,
      action: "REQUEST_JOB_CHANGES",
      targetPath: `jobs/${data.jobId}`,
      before,
      after: updates,
      rawIp: request.rawRequest.ip,
      metadata: { adminNote: data.adminNote },
    });

    return { success: true, jobId: data.jobId, status: "PENDING_REVIEW" };
  },
);

// ── 4. adminCloseJob ─────────────────────────────────────────────────────────
const CloseJobSchema = z.object({
  jobId: z.string(),
  reason: z.string().optional(),
});

export const adminCloseJob = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(CloseJobSchema, request.data);

    const jobRef = db().collection(Collections.JOBS).doc(data.jobId);
    const snap = await jobRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Job not found.");
    const before = snap.data();

    const updates = {
      status: "CLOSED",
      closedReason: data.reason || "ADMIN_MANUAL_CLOSE",
      closedBy: actorUid,
      closedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await jobRef.update(updates);

    await writeAudit({
      actorUid,
      role: actorRole,
      action: "CLOSE_JOB",
      targetPath: `jobs/${data.jobId}`,
      before,
      after: updates,
      rawIp: request.rawRequest.ip,
      metadata: { reason: data.reason },
    });

    return { success: true, jobId: data.jobId, status: "CLOSED" };
  },
);

// ── 5. adminMarkDuplicate ───────────────────────────────────────────────────
const MarkDuplicateSchema = z.object({
  jobId: z.string(),
  canonicalJobId: z.string().optional(),
});

export const adminMarkDuplicate = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(MarkDuplicateSchema, request.data);

    const jobRef = db().collection(Collections.JOBS).doc(data.jobId);
    const snap = await jobRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Job not found.");
    const before = snap.data();

    const updates = {
      status: "DUPLICATE",
      canonicalJobId: data.canonicalJobId ?? null,
      markedDuplicateBy: actorUid,
      markedDuplicateAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await jobRef.update(updates);

    await writeAudit({
      actorUid,
      role: actorRole,
      action: "MARK_JOB_DUPLICATE",
      targetPath: `jobs/${data.jobId}`,
      before,
      after: updates,
      rawIp: request.rawRequest.ip,
    });

    return { success: true, jobId: data.jobId, status: "DUPLICATE" };
  },
);

// ── 6. adminReverifyJob ──────────────────────────────────────────────────────
const ReverifyJobSchema = z.object({
  jobId: z.string(),
});

export const adminReverifyJob = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(ReverifyJobSchema, request.data);

    const jobRef = db().collection(Collections.JOBS).doc(data.jobId);
    const snap = await jobRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Job not found.");
    const job = snap.data()!;

    const companySnap = await db().collection(Collections.COMPANIES).doc(job.companyId).get();
    const company = companySnap.exists ? companySnap.data()! : {};

    const evalResult = await runRules({
      source: { enabled: true },
      company: {
        id: job.companyId,
        domain: company.slug || company.website,
        sourceVerified: company.isVerified === true,
      },
      job: {
        id: snap.id,
        title: job.title,
        companyId: job.companyId,
        companyName: job.companyName,
        applyUrl: job.applyUrl,
        description: job.description,
        location: job.location,
        city: job.city,
        remote: job.workMode === "REMOTE",
        postedAt: job.postedAt?.toDate(),
        firstSeenAt: job.lastSeenAt?.toDate(),
        deadline: job.deadline?.toDate(),
      },
      aiExtraction: {
        confidence: 0.9,
        isValidSchema: true,
        category: job.category,
      },
    });

    const newStatus = evalResult.allPass ? "ACTIVE" : "PENDING_REVIEW";
    const newVerificationState = evalResult.allPass ? "VERIFIED" : "UNVERIFIED";

    const updates = {
      status: newStatus,
      "verification.state": newVerificationState,
      "verification.checkedAt": admin.firestore.FieldValue.serverTimestamp(),
      "verification.rules": evalResult.results.filter((r) => r.result === "PASS").map((r) => r.ruleCode),
      reviewReasons: evalResult.reasonCodes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await jobRef.update(updates);

    await writeAudit({
      actorUid,
      role: actorRole,
      action: "REVERIFY_JOB",
      targetPath: `jobs/${data.jobId}`,
      before: job,
      after: updates,
      rawIp: request.rawRequest.ip,
    });

    return {
      success: true,
      allPass: evalResult.allPass,
      rules: evalResult.results,
      status: newStatus,
    };
  },
);

// ── 7. adminRerunExtraction ──────────────────────────────────────────────────
const RerunExtractionSchema = z.object({
  jobId: z.string(),
});

export const adminRerunExtraction = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(RerunExtractionSchema, request.data);

    const jobRef = db().collection(Collections.JOBS).doc(data.jobId);
    const snap = await jobRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Job not found.");
    const job = snap.data()!;

    // Invalidate extraction cache
    const descHash = hashDescription(job.description || "");
    await db().collection("aiExtractionCache").doc(descHash).delete();

    // Rerun Gemini extraction
    const extraction = await extractJobWithGemini(job.description || "", {
      skipCache: true,
      jobId: data.jobId,
    });

    if (!extraction.success || !extraction.data) {
      throw new HttpsError(
        "failed-precondition",
        `Extraction re-run failed: ${extraction.error || "Invalid AI output"}`,
      );
    }

    const ai = extraction.data;
    const updates = {
      aiSummary: ai.summary,
      category: ai.category,
      jobType: ai.jobType,
      requiredSkills: ai.requiredSkills,
      preferredSkills: ai.preferredSkills,
      minEdu: ai.minEdu,
      expMin: ai.expMin,
      expMax: ai.expMax,
      expLevel: ai.expLevel,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await jobRef.update(updates);

    await writeAudit({
      actorUid,
      role: actorRole,
      action: "RERUN_AI_EXTRACTION",
      targetPath: `jobs/${data.jobId}`,
      before: job,
      after: updates,
      rawIp: request.rawRequest.ip,
    });

    return { success: true, extraction: ai };
  },
);

// ── 8. adminBulkAction ───────────────────────────────────────────────────────
const BulkActionSchema = z.object({
  action: z.enum(["CLOSE", "REJECT"]),
  jobIds: z.array(z.string()).min(1).max(50, "Bulk actions capped at 50 IDs"),
  reason: z.string().min(3, "Reason is required"),
});

export const adminBulkAction = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(BulkActionSchema, request.data);

    const targetStatus = data.action === "CLOSE" ? "CLOSED" : "REJECTED";
    const batch = db().batch();

    for (const jobId of data.jobIds) {
      const ref = db().collection(Collections.JOBS).doc(jobId);
      batch.update(ref, {
        status: targetStatus,
        bulkActionReason: data.reason,
        bulkActionBy: actorUid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    await writeAudit({
      actorUid,
      role: actorRole,
      action: `BULK_${data.action}`,
      targetPath: "jobs",
      before: null,
      after: { action: data.action, count: data.jobIds.length, targetStatus },
      rawIp: request.rawRequest.ip,
      metadata: { jobIds: data.jobIds, reason: data.reason },
    });

    return { success: true, count: data.jobIds.length, targetStatus };
  },
);

// ── 9. claimReviewItem (10-minute soft lock) ─────────────────────────────────
const ClaimReviewSchema = z.object({
  jobId: z.string(),
});

export const claimReviewItem = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(ClaimReviewSchema, request.data);

    const jobRef = db().collection(Collections.JOBS).doc(data.jobId);

    return db().runTransaction(async (transaction) => {
      const snap = await transaction.get(jobRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Job not found.");
      }

      const jobData = snap.data()!;
      const claim = jobData.reviewClaim;

      if (claim) {
        const claimedAt = claim.claimedAt?.toDate() ?? new Date(0);
        const claimedBy = claim.claimedBy;
        const now = Date.now();
        const tenMinutes = 10 * 60 * 1000;

        // If claimed by another admin and 10 minutes have NOT elapsed:
        if (claimedBy !== actorUid && now - claimedAt.getTime() < tenMinutes) {
          const remainingSec = Math.ceil((tenMinutes - (now - claimedAt.getTime())) / 1000);
          throw new HttpsError(
            "failed-precondition",
            `Item is currently locked for review by another administrator. Lock expires in ${remainingSec}s.`,
          );
        }
      }

      // Acquire or refresh 10-minute soft lock
      transaction.update(jobRef, {
        reviewClaim: {
          claimedBy: actorUid,
          claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      return {
        success: true,
        jobId: data.jobId,
        claimedBy: actorUid,
        expiresInSeconds: 600,
      };
    });
  },
);
