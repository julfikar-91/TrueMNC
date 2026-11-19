// functions/src/callables/updateAppConfig.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Roles } from "../utils/config";
import { requireRole } from "../utils/auth";
import { writeAudit } from "../utils/audit";
import { validate } from "../utils/validators";
import { logInfo, logError } from "../utils/logger";

const FN = "updateAppConfig";

export const UpdateAppConfigSchema = z.object({
  minAppVersion: z.string().min(1, "minAppVersion is required"),
  currentAppVersion: z.string().optional(),
  maintenanceMode: z.boolean().default(false),
  featureFlags: z
    .object({
      enableAiScoring: z.boolean().default(true),
      enableJobAlerts: z.boolean().default(true),
      enableCompanyVerification: z.boolean().default(true),
      enableResumeParsing: z.boolean().default(true),
      enableDirectApply: z.boolean().default(true),
    })
    .optional(),
  notifications: z
    .object({
      maxPushesPerDay: z.number().int().min(0).max(50).default(3),
      quietHours: z
        .object({
          start: z.string().default("22:00"),
          end: z.string().default("08:00"),
          timezone: z.string().default("Asia/Kolkata"),
        })
        .optional(),
    })
    .optional(),
  aiModels: z
    .object({
      geminiMatchModel: z.string().default("gemini-1.5-pro"),
      geminiSummaryModel: z.string().default("gemini-1.5-flash"),
      geminiParserModel: z.string().default("gemini-1.5-pro"),
    })
    .optional(),
  legal: z
    .object({
      termsUrl: z.string().url().or(z.literal("")).optional(),
      privacyUrl: z.string().url().or(z.literal("")).optional(),
    })
    .optional(),
});

export type UpdateAppConfigInput = z.infer<typeof UpdateAppConfigSchema>;

export const updateAppConfig = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    // Only SUPER_ADMIN can invoke this
    const actorRole = await requireRole(request, [Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;

    const validatedData = validate(UpdateAppConfigSchema, request.data);

    logInfo(FN, "Updating app configuration", { actorUid });

    try {
      const appConfigRef = db().collection("config").doc("app");
      const currentSnap = await appConfigRef.get();
      const previousData = currentSnap.exists ? currentSnap.data() : null;

      const payload = {
        ...validatedData,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: actorUid,
      };

      // 1. Update main config/app document
      await appConfigRef.set(payload, { merge: true });

      // 2. Create version history snapshot
      const versionRef = await appConfigRef.collection("versions").add({
        config: validatedData,
        changedBy: actorUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 3. Write immutable audit log
      await writeAudit({
        actorUid,
        role: actorRole,
        action: "UPDATE_APP_CONFIG",
        targetPath: "config/app",
        before: previousData,
        after: payload,
        rawIp: request.rawRequest.ip,
        metadata: {
          versionId: versionRef.id,
        },
      });

      logInfo(FN, "App configuration successfully updated", {
        actorUid,
        versionId: versionRef.id,
      });

      return {
        success: true,
        versionId: versionRef.id,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logError(FN, err, { actorUid });
      throw new HttpsError("internal", "Failed to update app configuration.");
    }
  },
);
