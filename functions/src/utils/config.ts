// functions/src/utils/config.ts
// Central configuration for all Cloud Functions.

import * as admin from "firebase-admin";

// ── Region ────────────────────────────────────────────────────────────────────
/** All Gen 2 functions MUST deploy to this region. */
export const REGION = "asia-south1" as const;

// ── Firebase Admin ────────────────────────────────────────────────────────────
/** Initialise admin SDK once (safe to call multiple times). */
export function initAdmin(): admin.app.App {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  return admin.app();
}

export const db = (): admin.firestore.Firestore => admin.firestore();
export const auth = (): admin.auth.Auth => admin.auth();
export const storage = (): admin.storage.Storage => admin.storage();

// ── Firestore collection names ────────────────────────────────────────────────
export const Collections = {
  USERS: "users",
  JOBS: "jobs",
  COMPANIES: "companies",
  APPLICATIONS: "applications",
  RESUMES: "resumes",
  REPORTS: "reports",
  NOTIFICATIONS: "notifications",
  AUDIT_LOGS: "auditLogs",
} as const;

// ── User roles (mirror client constants) ─────────────────────────────────────
export const Roles = {
  USER: "USER",
  ADMIN: "ADMIN",
  SUPER_ADMIN: "SUPER_ADMIN",
} as const;

export type Role = (typeof Roles)[keyof typeof Roles];

// ── Gemini model ──────────────────────────────────────────────────────────────
/** Server-side only — never expose to client. */
export const GEMINI_MODEL = "gemini-1.5-pro";
