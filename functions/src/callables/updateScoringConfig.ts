// functions/src/callables/updateScoringConfig.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Roles } from "../utils/config";
import { requireRole } from "../utils/auth";
import { writeAudit } from "../utils/audit";
import { validate } from "../utils/validators";
import { logInfo, logError } from "../utils/logger";

const FN = "updateScoringConfig";

export const UpdateScoringConfigSchema = z
  .object({
    weights: z.object({
      skills: z.number().min(0).max(100),
      education: z.number().min(0).max(100),
      experience: z.number().min(0).max(100),
      location: z.number().min(0).max(100),
      preference: z.number().min(0).max(100),
    }),
    threshold: z.number().min(0).max(100).default(55),
    softCapCoverage: z.number().default(0.5),
    softCap: z.number().min(0).max(100).default(74),
    labelCutoffs: z
      .object({
        excellent: z.number().default(80),
        good: z.number().default(65),
        fair: z.number().default(55),
      })
      .default({ excellent: 80, good: 65, fair: 55 }),
    description: z.string().optional(),
  })
  .refine(
    (cfg) => {
      const sum =
        cfg.weights.skills +
        cfg.weights.education +
        cfg.weights.experience +
        cfg.weights.location +
        cfg.weights.preference;
      return sum === 100;
    },
    {
      message: "Scoring weights must sum to exactly 100",
    },
  );

export type UpdateScoringConfigInput = z.infer<typeof UpdateScoringConfigSchema>;

export const updateScoringConfig = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    // Only SUPER_ADMIN can invoke this
    const actorRole = await requireRole(request, [Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;

    const validatedData = validate(UpdateScoringConfigSchema, request.data);

    logInfo(FN, "Updating scoring configuration", { actorUid });

    try {
      const scoringRef = db().collection("config").doc("scoring_v1");
      const currentSnap = await scoringRef.get();
      const previousData = currentSnap.exists ? currentSnap.data() : null;

      const payload = {
        ...validatedData,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: actorUid,
      };

      // 1. Update main config/scoring_v1 document
      await scoringRef.set(payload, { merge: true });

      // 2. Create version history snapshot
      const versionRef = await scoringRef.collection("versions").add({
        config: validatedData,
        changedBy: actorUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 3. Write immutable audit log
      await writeAudit({
        actorUid,
        role: actorRole,
        action: "UPDATE_SCORING_CONFIG",
        targetPath: "config/scoring_v1",
        before: previousData,
        after: payload,
        rawIp: request.rawRequest.ip,
        metadata: {
          versionId: versionRef.id,
        },
      });

      logInfo(FN, "Scoring configuration successfully updated", {
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
      throw new HttpsError("internal", "Failed to update scoring configuration.");
    }
  },
);
