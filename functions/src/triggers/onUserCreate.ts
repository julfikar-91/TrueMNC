// functions/src/triggers/onUserCreate.ts
// Firestore trigger: when a user document is created, set default role claim.
import { onDocumentCreated } from "firebase-functions/v2/firestore";

import { REGION, auth, Collections, Roles } from "../utils/config";
import { logInfo, logError } from "../utils/logger";

const FN = "onUserCreate";

export const onUserCreate = onDocumentCreated(
  { document: `${Collections.USERS}/{uid}`, region: REGION },
  async (event) => {
    const uid = event.params.uid;
    logInfo(FN, "New user created", { uid });

    try {
      // Check if claims already set (e.g. invited admin)
      const existing = await auth().getUser(uid);
      const claims = existing.customClaims as Record<string, string> | undefined;

      if (!claims?.["role"]) {
        // Default role: USER
        await auth().setCustomUserClaims(uid, { role: Roles.USER });
        logInfo(FN, "Default USER role set", { uid });
      }
    } catch (err) {
      logError(FN, err, { uid });
    }
  },
);
