// functions/src/callables/adminUpdateReport.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections, Roles } from "../utils/config";
import { requireRole } from "../utils/auth";
import { writeAudit } from "../utils/audit";
import { validate } from "../utils/validators";
import { logInfo } from "../utils/logger";

const FN = "adminUpdateReport";

export const REPORT_STATUSES = ["OPEN", "IN_REVIEW", "RESOLVED", "REJECTED"] as const;

export const AdminUpdateReportInputSchema = z.object({
  reportId: z.string().min(1, "reportId is required"),
  status: z.enum(REPORT_STATUSES),
  adminNote: z.string().max(1000).optional(),
});

export const adminUpdateReport = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(AdminUpdateReportInputSchema, request.data);

    const reportRef = db().collection(Collections.REPORTS).doc(data.reportId);
    const snap = await reportRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", `Report ${data.reportId} not found.`);
    }

    const before = snap.data();
    const updates: Record<string, any> = {
      status: data.status,
      adminNote: data.adminNote?.trim() || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (data.status === "RESOLVED" || data.status === "REJECTED") {
      updates.resolvedBy = actorUid;
      updates.resolvedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await reportRef.update(updates);

    // ── Reporter In-App Notification ─────────────────────────────────────────
    const reporterUid = before?.reporterUid;
    if (reporterUid) {
      const notifRef = db()
        .collection(Collections.USERS)
        .doc(reporterUid)
        .collection(Collections.NOTIFICATIONS)
        .doc();

      const notifBody = data.adminNote?.trim() ||
        `Your report concerning "${before?.category || "issue"}" has been marked as ${data.status}.`;

      await notifRef.set({
        id: notifRef.id,
        title: "Report updates",
        body: notifBody,
        type: "REPORT_UPDATE",
        reportId: data.reportId,
        status: data.status,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // ── Audit Log ────────────────────────────────────────────────────────────
    await writeAudit({
      actorUid,
      role: actorRole,
      action: "UPDATE_REPORT",
      targetPath: `reports/${data.reportId}`,
      before,
      after: updates,
      rawIp: request.rawRequest.ip,
    });

    logInfo(FN, "Admin updated report status", {
      reportId: data.reportId,
      status: data.status,
      actorUid,
    });

    return { success: true };
  }
);
