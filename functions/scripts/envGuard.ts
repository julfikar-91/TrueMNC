// functions/scripts/envGuard.ts
// Environment guard for all administrative and seed scripts.
// Strictly prevents seed operations against production environments.

import type * as admin from "firebase-admin";

export async function initializeScriptAdmin(): Promise<admin.firestore.Firestore> {
  const adminSdk = (await import("firebase-admin")) as unknown as typeof admin;

  if (adminSdk.apps.length === 0) {
    adminSdk.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || "truemnc-dev",
    });
  }

  const isEmulator =
    Boolean(process.env.FUNCTIONS_EMULATOR) ||
    Boolean(process.env.FIRESTORE_EMULATOR_HOST) ||
    process.env.NODE_ENV === "development" ||
    process.env.NODE_ENV === "test";

  const projectId =
    process.env.GCLOUD_PROJECT || adminSdk.app().options.projectId || "truemnc-dev";

  if (
    projectId === "truemnc-prod" ||
    (!isEmulator && process.env.NODE_ENV === "production")
  ) {
    console.error(
      "❌ FATAL ERROR: Seed and bootstrap scripts are strictly FORBIDDEN in production environment (truemnc-prod).",
    );
    process.exit(1);
  }

  console.log(
    `[ENV-GUARD] Safe environment confirmed. Target Project: ${projectId} (Emulator: ${isEmulator})`,
  );

  return adminSdk.firestore();
}
