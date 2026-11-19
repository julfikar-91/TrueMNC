// functions/src/callables/parseResume.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, db, storage, Collections } from "../utils/config";
import { validate } from "../utils/validators";
import { logInfo, logWarn, logError } from "../utils/logger";
import { validateAndExtractText, postProcessResume } from "../ai/postProcess";
import { extractResume } from "../ai/extractResume";

const FN = "parseResume";

const ParseResumeInputSchema = z.object({
  resumeId: z.string().min(1, "resumeId is required"),
  storagePath: z.string().optional(),
  fileBufferBase64: z.string().optional(),
});

export type ResumeProgressStage =
  | "uploading"
  | "reading"
  | "personal"
  | "skills"
  | "education"
  | "experience"
  | "creating";

export const parseResume = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required to parse resume.");
    }

    const { uid } = request.auth;
    const input = validate(ParseResumeInputSchema, request.data);
    const { resumeId } = input;

    logInfo(FN, "Starting resume parse process", { resumeId, uid });

    // 1. Rate limiting check: Max 3 parses per day per user
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const parsesTodaySnap = await db()
      .collection(Collections.RESUMES)
      .where("uid", "==", uid)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
      .get();

    // Filter out deleted ones if any, or count total attempts
    if (parsesTodaySnap.size >= 3) {
      logWarn(FN, "Rate limit reached for resume parsing", { uid, count: parsesTodaySnap.size });
      throw new HttpsError(
        "resource-exhausted",
        "RATE_LIMITED: Maximum 3 resume parses allowed per day."
      );
    }

    const resumeRef = db().collection(Collections.RESUMES).doc(resumeId);

    // Initialise or update resume doc to PROCESSING
    await resumeRef.set(
      {
        id: resumeId,
        uid,
        status: "PROCESSING",
        progress: "uploading",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Progress update helper
    const updateProgress = async (stage: ResumeProgressStage) => {
      try {
        await resumeRef.update({
          progress: stage,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        logWarn(FN, "Failed to update resume progress", { stage, resumeId });
      }
    };

    let fileBuffer: Buffer;

    // 2. Step: uploading -> Retrieve File Buffer
    try {
      if (input.fileBufferBase64) {
        fileBuffer = Buffer.from(input.fileBufferBase64, "base64");
      } else if (input.storagePath) {
        const bucket = storage().bucket();
        const [downloaded] = await bucket.file(input.storagePath).download();
        fileBuffer = downloaded;
      } else {
        // Look up storagePath in resumes collection
        const resumeSnap = await resumeRef.get();
        const storedPath = resumeSnap.data()?.storagePath;
        if (!storedPath) {
          throw new Error("No storagePath or file buffer provided.");
        }
        const bucket = storage().bucket();
        const [downloaded] = await bucket.file(storedPath).download();
        fileBuffer = downloaded;
      }
    } catch (err) {
      logError(FN, "Failed to obtain resume file buffer", { resumeId, err });
      await resumeRef.update({
        status: "FAILED_UNREADABLE",
        errorCode: "RESUME_UNREADABLE",
        errorMessage: "Unable to retrieve resume file.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new HttpsError("invalid-argument", "Failed to retrieve resume file.");
    }

    // 3. Step: reading -> Validate file format & extract text
    await updateProgress("reading");

    const validation = validateAndExtractText(fileBuffer);
    if (!validation.valid) {
      logWarn(FN, "Resume file validation failed", {
        resumeId,
        errorCode: validation.errorCode,
        errorMessage: validation.errorMessage,
      });

      await resumeRef.update({
        status: "FAILED_UNREADABLE",
        errorCode: validation.errorCode ?? "RESUME_UNREADABLE",
        errorMessage: validation.errorMessage ?? "File validation failed.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw new HttpsError("invalid-argument", `${validation.errorCode}: ${validation.errorMessage}`);
    }

    const resumeText = validation.text;

    // 4. Progress stages: personal, skills, education, experience
    await updateProgress("personal");
    await updateProgress("skills");
    await updateProgress("education");
    await updateProgress("experience");

    // 5. Invoke Gemini AI Extraction Engine
    const extractionResult = await extractResume(resumeText, { resumeId, uid });

    if (!extractionResult.success || !extractionResult.data) {
      logError(FN, "AI resume extraction failed", {
        resumeId,
        reason: extractionResult.reason,
        error: extractionResult.error,
      });

      await resumeRef.update({
        status: "FAILED_AI",
        errorCode: extractionResult.reason ?? "AI_INVALID",
        errorMessage: extractionResult.error ?? "Failed to extract structured data from resume.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw new HttpsError(
        "internal",
        `${extractionResult.reason ?? "FAILED_AI"}: ${extractionResult.error ?? "AI extraction failed."}`
      );
    }

    // 6. Post-process the extracted data
    const { draft, warnings, status } = postProcessResume(
      extractionResult.data,
      resumeText
    );

    // 7. Step: creating -> Save draft to resumeParses and update resume record
    await updateProgress("creating");

    const parseDocRef = db().collection("resumeParses").doc(resumeId);
    await parseDocRef.set({
      resumeId,
      uid,
      draft,
      warnings,
      status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await resumeRef.update({
      status,
      mimeType: validation.mimeType,
      fileSize: fileBuffer.length,
      pageCount: validation.pageCount ?? 1,
      warningsCount: warnings.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logInfo(FN, "Resume parsed successfully", {
      resumeId,
      uid,
      status,
      warningsCount: warnings.length,
    });

    return {
      success: true,
      resumeId,
      status,
      warnings,
      draft,
    };
  }
);
