// functions/src/utils/auth.ts
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { auth, Role, Roles } from "./config";
import { logWarn } from "./logger";

/**
 * Validates that the caller is authenticated.
 * Throws HttpsError('unauthenticated') if not signed in.
 */
export function requireAuth(req: CallableRequest): string {
  if (!req.auth || !req.auth.uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  return req.auth.uid;
}

/**
 * Re-checks the caller's custom claims directly from the Firebase Auth backend
 * to prevent stale or manipulated client tokens from bypassing security checks.
 *
 * Throws HttpsError('permission-denied') if the user does not possess one of the allowed roles.
 */
export async function requireRole(
  req: CallableRequest,
  allowedRoles: Role[],
): Promise<Role> {
  const uid = requireAuth(req);

  try {
    // Always re-check the custom claim from the Auth service server-side
    const userRecord = await auth().getUser(uid);
    const serverRole = (userRecord.customClaims?.role as Role) || Roles.USER;

    if (!allowedRoles.includes(serverRole)) {
      logWarn("requireRole", "Access denied: insufficient role privileges", {
        actorUid: uid,
        serverRole,
        allowedRoles,
      });
      throw new HttpsError(
        "permission-denied",
        "Permission denied: Insufficient role permissions.",
      );
    }

    return serverRole;
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("permission-denied", "Permission denied: Role verification failed.");
  }
}
