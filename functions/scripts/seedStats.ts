// functions/scripts/seedStats.ts
import type * as admin from "firebase-admin";
import { initializeScriptAdmin } from "./envGuard";

export const INITIAL_GLOBAL_STATS = {
  // Counters for every JobStatus = 0
  DRAFT_RAW: 0,
  PENDING_REVIEW: 0,
  ACTIVE: 0,
  CLOSING_SOON: 0,
  EXPIRED: 0,
  CLOSED: 0,
  REJECTED: 0,
  DUPLICATE: 0,

  // Nested map for grouped status queries
  jobCountsByStatus: {
    DRAFT_RAW: 0,
    PENDING_REVIEW: 0,
    ACTIVE: 0,
    CLOSING_SOON: 0,
    EXPIRED: 0,
    CLOSED: 0,
    REJECTED: 0,
    DUPLICATE: 0,
  },

  // Corporate entity counters
  companies: 0,
  sources: 0,

  // General counters
  totalJobs: 0,
  users: 0,
  reports: 0,
  verifiedCompanies: 0,
};

export async function seedStats(db?: admin.firestore.Firestore): Promise<{ document: string }> {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const adminSdk = require("firebase-admin") as typeof admin;
  const firestore = db || (await initializeScriptAdmin());
  const statsDocRef = firestore.collection("stats").doc("global");

  console.log("[STATS-SEED] Preparing stats/global initial document...");

  await statsDocRef.set(
    {
      ...INITIAL_GLOBAL_STATS,
      updatedAt: adminSdk.firestore.FieldValue.serverTimestamp(),
      createdAt: adminSdk.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log("[STATS-SEED] ✅ Successfully initialized stats/global counters.");
  return { document: "stats/global" };
}

if (typeof require !== "undefined" && require.main === module) {
  seedStats()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("[STATS-SEED] ❌ Failed:", err);
      process.exit(1);
    });
}
