// functions/src/tasks/dailyJobDigest.ts
// Scheduled task: fires daily to send job digest notifications to users.
import { onSchedule } from "firebase-functions/v2/scheduler";

import { REGION } from "../utils/config";
import { logInfo, logError } from "../utils/logger";

const FN = "dailyJobDigest";

export const dailyJobDigest = onSchedule(
  { schedule: "every day 09:00", timeZone: "Asia/Kolkata", region: REGION },
  async (_event) => {
    logInfo(FN, "Running daily job digest");

    try {
      // TODO: Query latest verified jobs
      // TODO: For each user with notifications enabled, send FCM digest
      logInfo(FN, "Daily digest complete");
    } catch (err) {
      logError(FN, err);
    }
  },
);
