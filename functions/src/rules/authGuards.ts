// functions/src/rules/authGuards.ts
// Shared auth guard helpers for callable functions.
import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { Roles, Role } from "../utils/config";

/** Throws if caller is not authenticated. */
export function requireAuth(request: CallableRequest): void {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
}

/** Throws if caller does not have the required role. */
export function requireRole(request: CallableRequest, role: Role): void {
  requireAuth(request);
  const callerRole = request.auth!.token["role"] as string | undefined;

  if (role === Roles.SUPER_ADMIN && callerRole !== Roles.SUPER_ADMIN) {
    throw new HttpsError("permission-denied", "SUPER_ADMIN required.");
  }

  if (role === Roles.ADMIN) {
    if (callerRole !== Roles.ADMIN && callerRole !== Roles.SUPER_ADMIN) {
      throw new HttpsError("permission-denied", "ADMIN role required.");
    }
  }
}

/** Throws if caller is neither the resource owner nor an admin. */
export function requireOwnerOrAdmin(
  request: CallableRequest,
  ownerUid: string,
): void {
  requireAuth(request);
  const uid = request.auth!.uid;
  const role = request.auth!.token["role"] as string | undefined;
  const isAdmin = role === Roles.ADMIN || role === Roles.SUPER_ADMIN;

  if (uid !== ownerUid && !isAdmin) {
    throw new HttpsError("permission-denied", "Not authorised.");
  }
}
