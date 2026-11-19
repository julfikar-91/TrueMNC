// functions/src/triggers/onJobUpdate.ts
// Firestore trigger: fires when a job document is updated.
// Guards against client attempts to set isVerified (server-only field).
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

import { REGION, Collections } from "../utils/config";
import { logInfo, logWarn } from "../utils/logger";

const FN = "onJobUpdate";

export const onJobUpdate = onDocumentUpdated(
  { document: `${Collections.JOBS}/{jobId}`, region: REGION },
  async (event) => {
    const jobId = event.params.jobId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    logInfo(FN, "Job updated", { jobId });

    // Detect if isVerified was changed outside server flow (should not happen
    // due to Firestore rules, but double-guard here)
    if (before["isVerified"] !== after["isVerified"] && after["isVerified"] === true) {
      logWarn(FN, "isVerified set to true — ensure this was done by server.", { jobId });
      // TODO: Audit log to admin subcollection
    }
  },
);
