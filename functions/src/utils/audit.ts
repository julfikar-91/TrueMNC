// functions/src/utils/audit.ts
import * as admin from "firebase-admin";
import { db, Collections, Role } from "./config";
import { hashIp, logInfo, logError } from "./logger";

export interface AuditLogParams {
  actorUid: string;
  role: Role | string;
  action: string;
  targetPath: string;
  before: unknown;
  after: unknown;
  rawIp?: string;
  metadata?: Record<string, unknown>;
}

export interface StoredAuditLog {
  id: string;
  actorUid: string;
  role: string;
  action: string;
  targetPath: string;
  before: unknown;
  after: unknown;
  at: admin.firestore.Timestamp | FirebaseFirestore.FieldValue;
  ipHash: string;
  metadata?: Record<string, unknown>;
}

/**
 * Immutable audit log writer. Reused across all admin operations.
 * Automatically hashes client IP and guarantees no PII is stored.
 */
export async function writeAudit(entry: AuditLogParams): Promise<string> {
  const ipHash = hashIp(entry.rawIp);

  const auditData = {
    actorUid: entry.actorUid,
    role: entry.role,
    action: entry.action,
    targetPath: entry.targetPath,
    before: entry.before ?? null,
    after: entry.after ?? null,
    at: admin.firestore.FieldValue.serverTimestamp(),
    ipHash,
    metadata: entry.metadata ?? {},
  };

  try {
    const docRef = await db().collection(Collections.AUDIT_LOGS).add(auditData);

    logInfo("writeAudit", "Audit log created", {
      auditId: docRef.id,
      actorUid: entry.actorUid,
      action: entry.action,
      targetPath: entry.targetPath,
      ipHash,
    });

    return docRef.id;
  } catch (err) {
    logError("writeAudit", err, {
      actorUid: entry.actorUid,
      action: entry.action,
      targetPath: entry.targetPath,
    });
    throw err;
  }
}
