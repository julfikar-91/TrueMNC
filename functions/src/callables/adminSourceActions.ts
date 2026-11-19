// functions/src/callables/adminSourceActions.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, Collections, Roles } from "../utils/config";
import { requireRole } from "../utils/auth";
import { writeAudit } from "../utils/audit";
import { validate } from "../utils/validators";
import { getAdapter } from "../adapters/registry";
import { SourceDoc } from "../adapters/types";
import { runRules } from "../rules/verificationRules";
import { executeCollectSource } from "../tasks/collectionPipeline";
import { logInfo, logWarn, logError } from "../utils/logger";

const FN = "adminSourceActions";

// Rate limiting map for adminTestSource and adminRunCollectionNow
const testSourceRateLimits = new Map<string, number>();
const runNowRateLimits = new Map<string, number>();

// ── 1. adminUpsertSource ─────────────────────────────────────────────────────
const UpsertSourceSchema = z.object({
  id: z.string().optional(),
  companyId: z.string().min(1, "companyId is required"),
  type: z.enum([
    "GREENHOUSE",
    "LEVER",
    "SMARTRECRUITERS",
    "OFFICIAL_FEED",
    "CAREERS_PAGE",
  ]),
  url: z.string().url("Valid URL required"),
  config: z.record(z.unknown()).optional().default({}),
  secretRef: z.string().nullable().optional(), // Name of secret reference ONLY, never secret value
  intervalMin: z.number().int().min(60, "intervalMin must be at least 60 minutes").default(360),
  enabled: z.boolean().default(false),
});

export const adminUpsertSource = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(UpsertSourceSchema, request.data);

    logInfo(FN, "adminUpsertSource invoked", { actorUid, companyId: data.companyId });

    // Validate that secretRef is only a key name, not an inline secret
    if (data.secretRef && (data.secretRef.includes("=") || data.secretRef.length > 100)) {
      throw new HttpsError(
        "invalid-argument",
        "secretRef must be a valid Secret Manager key identifier only.",
      );
    }

    try {
      const sourceCol = db().collection("sources");
      const isNew = !data.id;
      const docRef = isNew ? sourceCol.doc() : sourceCol.doc(data.id!);

      let previousData: unknown = null;
      if (!isNew) {
        const snap = await docRef.get();
        if (snap.exists) previousData = snap.data();
      }

      // New source must always start with enabled=false until verified
      const enabled = isNew ? false : data.enabled;

      const payload = {
        companyId: data.companyId,
        type: data.type,
        url: data.url,
        config: data.config,
        secretRef: data.secretRef ?? null,
        intervalMin: data.intervalMin,
        enabled,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: actorUid,
        ...(isNew ? { createdAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
      };

      await docRef.set(payload, { merge: true });

      // Write audit log
      await writeAudit({
        actorUid,
        role: actorRole,
        action: isNew ? "CREATE_SOURCE" : "UPDATE_SOURCE",
        targetPath: `sources/${docRef.id}`,
        before: previousData,
        after: payload,
        rawIp: request.rawRequest.ip,
      });

      return {
        success: true,
        sourceId: docRef.id,
        enabled,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logError(FN, err, { actorUid });
      throw new HttpsError("internal", "Failed to upsert source.");
    }
  },
);

// ── 2. adminTestSource ───────────────────────────────────────────────────────
const TestSourceSchema = z.object({
  type: z.enum([
    "GREENHOUSE",
    "LEVER",
    "SMARTRECRUITERS",
    "OFFICIAL_FEED",
    "CAREERS_PAGE",
  ]),
  url: z.string().url(),
  companyId: z.string(),
  config: z.record(z.unknown()).optional().default({}),
});

export const adminTestSource = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(TestSourceSchema, request.data);

    // Rate limit: 1 per 30 seconds per actor
    const lastTest = testSourceRateLimits.get(actorUid) ?? 0;
    if (Date.now() - lastTest < 30000) {
      throw new HttpsError(
        "resource-exhausted",
        "Test source rate limit reached. Please wait 30 seconds before testing again.",
      );
    }
    testSourceRateLimits.set(actorUid, Date.now());

    logInfo(FN, "adminTestSource dry-run invoked", { actorUid, type: data.type });

    try {
      const adapter = getAdapter(data.type);
      const fakeSource: SourceDoc = {
        id: "dry-run-test",
        companyId: data.companyId,
        type: data.type,
        url: data.url,
        enabled: true,
        config: data.config,
      };

      // Fetch sample jobs without writing to Firestore
      const rawJobs = await adapter.fetchJobs(fakeSource);
      const samples = rawJobs.slice(0, 3);

      const companyDoc = await db()
        .collection(Collections.COMPANIES)
        .doc(data.companyId)
        .get();
      const companyData = companyDoc.exists ? companyDoc.data()! : {};

      // Run R1-R8 verification rules on each sample
      const evaluatedSamples = [];
      for (const sample of samples) {
        const evalResult = await runRules({
          source: {
            enabled: true,
            config: data.config,
          },
          company: {
            id: data.companyId,
            domain: companyData.slug || companyData.website,
            sourceVerified: companyData.isVerified === true,
          },
          job: {
            title: sample.title,
            companyId: data.companyId,
            companyName: companyData.name,
            applyUrl: sample.applyUrl,
            description: sample.description,
            location: sample.location,
            city: sample.location,
            remote: sample.remote,
            sourceJobId: sample.sourceJobId,
            postedAt: sample.postedAt,
            firstSeenAt: new Date(),
            deadline: sample.deadline,
          },
          aiExtraction: {
            confidence: 0.9,
            isValidSchema: true,
            category: "Software Development",
          },
        });

        evaluatedSamples.push({
          rawJob: {
            sourceJobId: sample.sourceJobId,
            title: sample.title,
            applyUrl: sample.applyUrl,
            location: sample.location,
            remote: sample.remote,
          },
          rules: evalResult.results,
          allPass: evalResult.allPass,
          reasonCodes: evalResult.reasonCodes,
        });
      }

      return {
        success: true,
        totalFound: rawJobs.length,
        sampleCount: samples.length,
        samples: evaluatedSamples,
      };
    } catch (err: unknown) {
      logWarn(FN, "adminTestSource execution failed", { err: (err as Error).message });
      throw new HttpsError(
        "failed-precondition",
        `Source test failed: ${(err as Error).message}`,
      );
    }
  },
);

// ── 3. adminVerifySource ─────────────────────────────────────────────────────
const VerifySourceSchema = z.object({
  sourceId: z.string(),
  companyId: z.string(),
  adminSignOff: z.boolean().refine((val) => val === true, {
    message: "Admin sign-off confirmation is required",
  }),
  enableCollection: z.boolean().default(true),
});

export const adminVerifySource = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(VerifySourceSchema, request.data);

    logInfo(FN, "adminVerifySource invoked", { actorUid, sourceId: data.sourceId });

    try {
      const companyRef = db().collection(Collections.COMPANIES).doc(data.companyId);
      const sourceRef = db().collection("sources").doc(data.sourceId);

      const [compSnap, sourceSnap] = await Promise.all([companyRef.get(), sourceRef.get()]);
      if (!compSnap.exists || !sourceSnap.exists) {
        throw new HttpsError("not-found", "Company or source not found.");
      }

      // 1. Mark company.sourceVerified = true and set isVerified = true
      await companyRef.update({
        isVerified: true,
        sourceVerified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verifiedBy: actorUid,
      });

      // 2. Enable source collection if requested
      await sourceRef.update({
        enabled: data.enableCollection,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verifiedBy: actorUid,
      });

      // 3. Write audit log
      await writeAudit({
        actorUid,
        role: actorRole,
        action: "VERIFY_SOURCE",
        targetPath: `sources/${data.sourceId}`,
        before: { isVerified: false, enabled: false },
        after: { isVerified: true, enabled: data.enableCollection },
        rawIp: request.rawRequest.ip,
      });

      return {
        success: true,
        companyVerified: true,
        sourceEnabled: data.enableCollection,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logError(FN, err, { actorUid });
      throw new HttpsError("internal", "Failed to verify source.");
    }
  },
);

// ── 4. adminRunCollectionNow ─────────────────────────────────────────────────
const RunNowSchema = z.object({
  sourceId: z.string(),
});

export const adminRunCollectionNow = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const actorRole = await requireRole(request, [Roles.ADMIN, Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;
    const data = validate(RunNowSchema, request.data);

    // Rate limit: 1 per 10 minutes per source
    const lastRun = runNowRateLimits.get(data.sourceId) ?? 0;
    const tenMinutes = 10 * 60 * 1000;
    if (Date.now() - lastRun < tenMinutes) {
      const remainingMinutes = Math.ceil((tenMinutes - (Date.now() - lastRun)) / 60000);
      throw new HttpsError(
        "resource-exhausted",
        `Collection recently triggered for this source. Please wait ${remainingMinutes} more minute(s).`,
      );
    }
    runNowRateLimits.set(data.sourceId, Date.now());

    logInfo(FN, "adminRunCollectionNow invoked", { actorUid, sourceId: data.sourceId });

    try {
      // Execute collection task immediately
      await executeCollectSource({ sourceId: data.sourceId });

      await writeAudit({
        actorUid,
        role: actorRole,
        action: "TRIGGER_COLLECTION_MANUAL",
        targetPath: `sources/${data.sourceId}`,
        before: null,
        after: { triggeredAt: new Date() },
        rawIp: request.rawRequest.ip,
      });

      return {
        success: true,
        message: "Job collection executed successfully.",
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logError(FN, err, { actorUid });
      throw new HttpsError("internal", "Failed to run collection.");
    }
  },
);
