// functions/src/utils/logger.ts
import { logger } from "firebase-functions/v2";
import * as crypto from "crypto";

export { logger };

/**
 * Hash IP addresses using SHA-256 for privacy compliance (NO PII in logs).
 */
export function hashIp(ip?: string): string {
  if (!ip) return "unknown";
  return crypto.createHash("sha256").update(ip.trim()).digest("hex");
}

/**
 * Mask email address for logging if required, e.g. "j***e@example.com"
 */
export function maskEmail(email?: string): string {
  if (!email || !email.includes("@")) return "masked";
  const [local, domain] = email.split("@");
  if (local.length <= 2) return `*@${domain}`;
  return `${local[0]}***${local[local.length - 1]}@${domain}`;
}

/**
 * Sanitizes object by removing or masking potential PII fields.
 */
function sanitize(obj: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    const lowerKey = key.toLowerCase();
    if (lowerKey.includes("password") || lowerKey.includes("token") || lowerKey.includes("secret")) {
      result[key] = "[REDACTED]";
    } else if (lowerKey.includes("email") && typeof value === "string") {
      result[key] = maskEmail(value);
    } else if (lowerKey === "ip" && typeof value === "string") {
      result[key] = hashIp(value);
    } else if (value && typeof value === "object" && !Array.isArray(value)) {
      result[key] = sanitize(value as Record<string, unknown>);
    } else {
      result[key] = value;
    }
  }
  return result;
}

/** Structured log helper with context, strictly sanitizing any PII. */
export function logInfo(fnName: string, message: string, data?: Record<string, unknown>): void {
  const safeData = data ? sanitize(data) : {};
  logger.info(`[${fnName}] ${message}`, safeData);
}

export function logError(fnName: string, error: unknown, data?: Record<string, unknown>): void {
  const safeData = data ? sanitize(data) : {};
  logger.error(`[${fnName}] ERROR: ${error instanceof Error ? error.message : String(error)}`, {
    error: error instanceof Error ? error.stack : String(error),
    ...safeData,
  });
}

export function logWarn(fnName: string, message: string, data?: Record<string, unknown>): void {
  const safeData = data ? sanitize(data) : {};
  logger.warn(`[${fnName}] ${message}`, safeData);
}
