// functions/src/callables/setUserRole.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { z } from "zod";

import { REGION, auth, db, Collections, Roles, Role } from "../utils/config";
import { requireRole } from "../utils/auth";
import { writeAudit } from "../utils/audit";
import { validate } from "../utils/validators";
import { logInfo, logError, logWarn } from "../utils/logger";

const FN = "setUserRole";

const SetUserRoleSchema = z
  .object({
    targetEmail: z.string().email("Invalid email format").optional(),
    targetUid: z.string().optional(),
    role: z.enum([Roles.USER, Roles.ADMIN, Roles.SUPER_ADMIN]),
  })
  .refine((data) => data.targetEmail || data.targetUid, {
    message: "Either targetEmail or targetUid must be provided.",
  });

export const setUserRole = onCall(
  {
    region: REGION,
    enforceAppCheck: true, // Requirement 4: Enforce App Check
  },
  async (request) => {
    // Requirement 1 & 2: Only SUPER_ADMIN can invoke this, always re-checked server-side
    const actorRole = await requireRole(request, [Roles.SUPER_ADMIN]);
    const actorUid = request.auth!.uid;

    const data = validate(SetUserRoleSchema, request.data);
    const targetEmail = data.targetEmail?.toLowerCase().trim();
    const targetUid = data.targetUid?.trim();
    const newRole: Role = data.role;

    logInfo(FN, "Role change request received", {
      actorUid,
      targetEmail,
      targetUid,
      newRole,
    });

    try {
      // 1. Look up target user by UID or email
      let targetUser: admin.auth.UserRecord;
      try {
        if (targetUid) {
          targetUser = await auth().getUser(targetUid);
        } else if (targetEmail) {
          targetUser = await auth().getUserByEmail(targetEmail);
        } else {
          throw new HttpsError("invalid-argument", "Either targetEmail or targetUid is required.");
        }
      } catch (err: unknown) {
        if (err instanceof HttpsError) throw err;
        logWarn(FN, "Target user not found", { actorUid, targetEmail, targetUid });
        throw new HttpsError("not-found", "No user found with the specified email or UID.");
      }

      const previousRole = (targetUser.customClaims?.role as Role) || Roles.USER;

      // 2. Block removing the last SUPER_ADMIN
      if (previousRole === Roles.SUPER_ADMIN && newRole !== Roles.SUPER_ADMIN) {
        const superAdminsSnap = await db()
          .collection(Collections.USERS)
          .where("role", "==", Roles.SUPER_ADMIN)
          .get();

        if (superAdminsSnap.size <= 1) {
          logWarn(FN, "Blocked attempt to remove the last SUPER_ADMIN", {
            actorUid,
            targetUid: targetUser.uid,
          });
          throw new HttpsError(
            "failed-precondition",
            "Cannot remove the last SUPER_ADMIN from the system.",
          );
        }
      }

      // 3. Set custom claim on target user
      await auth().setCustomUserClaims(targetUser.uid, {
        ...(targetUser.customClaims || {}),
        role: newRole,
      });

      // 4. Mirror role to users/{uid}.role (server write)
      await db().collection(Collections.USERS).doc(targetUser.uid).set(
        {
          role: newRole,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // 5. Revoke refresh tokens so active sessions must re-authenticate with new claims
      await auth().revokeRefreshTokens(targetUser.uid);

      // 6. Write immutable audit log entry (actorUid, role, action, targetPath, before, after, at, ipHash)
      await writeAudit({
        actorUid,
        role: actorRole,
        action: "SET_USER_ROLE",
        targetPath: `${Collections.USERS}/${targetUser.uid}`,
        before: previousRole,
        after: newRole,
        rawIp: request.rawRequest.ip,
        metadata: {
          targetUid: targetUser.uid,
          tokensRevoked: true,
        },
      });

      logInfo(FN, "User role successfully updated", {
        actorUid,
        targetUid: targetUser.uid,
        previousRole,
        newRole,
      });

      return {
        success: true,
        targetUid: targetUser.uid,
        role: newRole,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logError(FN, err, { actorUid });
      throw new HttpsError("internal", "Failed to update user role.");
    }
  },
);
