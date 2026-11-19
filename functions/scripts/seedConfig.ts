// functions/scripts/seedConfig.ts
import type * as admin from "firebase-admin";
import { initializeScriptAdmin } from "./envGuard";
import { SKILLS_DICTIONARY } from "../src/matching/skills";

export const SCORING_CONFIG_V1 = {
  version: "v1",
  active: true,
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
  description: "Standard production scoring v1 - weights must sum to 100",
};

export const APP_CONFIG = {
  minAppVersion: "1.0.0",
  currentAppVersion: "1.0.0",
  maintenanceMode: false,
  featureFlags: {
    enableAiScoring: true,
    enableJobAlerts: true,
    enableCompanyVerification: true,
    enableResumeParsing: true,
    enableDirectApply: true,
  },
  notifications: {
    maxPushesPerDay: 3,
    quietHours: {
      start: "22:00",
      end: "08:00",
      timezone: "Asia/Kolkata",
    },
  },
  aiModels: {
    geminiMatchModel: "gemini-1.5-pro",
    geminiSummaryModel: "gemini-1.5-flash",
    geminiParserModel: "gemini-1.5-pro",
  },
  legal: {
    termsUrl: "https://truemnc.com/terms",
    privacyUrl: "https://truemnc.com/privacy",
  },
};

export async function seedConfig(db?: admin.firestore.Firestore): Promise<{ documents: string[] }> {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const adminSdk = require("firebase-admin") as typeof admin;
  const firestore = db || (await initializeScriptAdmin());
  const configCol = firestore.collection("config");
  const batch = firestore.batch();

  console.log("[CONFIG-SEED] Preparing configuration documents...");

  // 1. config/scoring_v1
  const scoringRef = configCol.doc("scoring_v1");
  batch.set(
    scoringRef,
    {
      ...SCORING_CONFIG_V1,
      updatedAt: adminSdk.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  // 2. config/app
  const appRef = configCol.doc("app");
  batch.set(
    appRef,
    {
      ...APP_CONFIG,
      updatedAt: adminSdk.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  // 3. config/skillsDictionary
  const skillsRef = configCol.doc("skillsDictionary");
  batch.set(
    skillsRef,
    {
      version: "1.0.0",
      totalSkills: SKILLS_DICTIONARY.length,
      categories: ["language", "framework", "db", "cloud", "tool", "soft"],
      canonicalIds: SKILLS_DICTIONARY.map((s) => s.canonicalId),
      updatedAt: adminSdk.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await batch.commit();
  console.log("[CONFIG-SEED] ✅ Successfully seeded config/scoring_v1, config/app, and config/skillsDictionary.");

  return { documents: ["config/scoring_v1", "config/app", "config/skillsDictionary"] };
}

if (typeof require !== "undefined" && require.main === module) {
  seedConfig()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("[CONFIG-SEED] ❌ Failed:", err);
      process.exit(1);
    });
}
