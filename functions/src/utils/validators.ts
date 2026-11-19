// functions/src/utils/validators.ts
import { z } from "zod";
import { HttpsError } from "firebase-functions/v2/https";

/** Parse and validate data with Zod; throws HttpsError on failure. */
export function validate<T>(schema: z.ZodSchema<T>, data: unknown): T {
  const result = schema.safeParse(data);
  if (!result.success) {
    const msg = result.error.errors.map((e) => e.message).join(", ");
    throw new HttpsError("invalid-argument", `Validation failed: ${msg}`);
  }
  return result.data;
}

// ── Shared schemas ────────────────────────────────────────────────────────────
export const UidSchema = z.string().min(1, "uid is required");

export const PaginationSchema = z.object({
  limit: z.number().int().min(1).max(100).default(20),
  lastDocId: z.string().optional(),
});
