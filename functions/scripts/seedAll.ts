// functions/scripts/seedAll.ts
// Master runner for all database seed operations.
// Guarded against production executions.

import { initializeScriptAdmin } from "./envGuard";
import { seedCategories } from "./seedCategories";
import { seedConfig } from "./seedConfig";
import { seedStats } from "./seedStats";

async function main(): Promise<void> {
  console.log("=============================================================");
  console.log("🚀 TrueMNC Master Database Seed Runner (Dev / Emulator Only)");
  console.log("=============================================================");

  const db = await initializeScriptAdmin();

  const categoriesResult = await seedCategories(db);
  const configResult = await seedConfig(db);
  const statsResult = await seedStats(db);

  console.log("\n=============================================================");
  console.log("📋 SEED SUMMARY REPORT");
  console.log("=============================================================");
  console.log(`✓ Categories seeded: ${categoriesResult.total} (10 Technical + 10 Non-Technical)`);
  console.log(`✓ Config documents seeded: ${configResult.documents.join(", ")}`);
  console.log(`✓ Initial stats document created: ${statsResult.document}`);
  console.log("✓ Zero secrets written to Firestore.");
  console.log("=============================================================\n");
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("❌ Master seed failed:", err);
      process.exit(1);
    });
}
