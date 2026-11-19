// functions/src/triggers/onApplicationCreate.ts
// Firestore trigger: fires when a user submits a job application.
// Sends FCM notification to the applicant and queues AI scoring.
import { onDocumentCreated } from "firebase-functions/v2/firestore";

import { REGION, Collections } from "../utils/config";
import { logInfo, logError } from "../utils/logger";

const FN = "onApplicationCreate";

export const onApplicationCreate = onDocumentCreated(
  { document: `${Collections.APPLICATIONS}/{appId}`, region: REGION },
  async (event) => {
    const appId = event.params.appId;
    const data = event.data?.data();
    if (!data) return;

    logInfo(FN, "New application", { appId, userId: data.userId });

    try {
      // Update application with server timestamp
      await event.data!.ref.update({ submittedAt: new Date() });

      // TODO: Enqueue AI scoring task via Cloud Tasks
      // TODO: Send FCM confirmation to applicant
    } catch (err) {
      logError(FN, err, { appId });
    }
  },
);
