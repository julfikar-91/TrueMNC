// functions/src/adapters/fcmAdapter.ts
// FCM notification helpers — server-side only.
import * as admin from "firebase-admin";
import { logInfo, logError } from "../utils/logger";

const FN = "fcmAdapter";

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/** Send FCM notification to a single device token. */
export async function sendToToken(
  token: string,
  payload: NotificationPayload,
): Promise<void> {
  logInfo(FN, "Sending FCM to token", { title: payload.title });
  try {
    await admin.messaging().send({
      token,
      notification: { title: payload.title, body: payload.body },
      data: payload.data,
      android: {
        priority: "high",
        notification: { channelId: "truemnc_jobs" },
      },
    });
  } catch (err) {
    logError(FN, err);
  }
}

/** Send FCM to a Firestore topic (e.g. job-alert-{category}). */
export async function sendToTopic(
  topic: string,
  payload: NotificationPayload,
): Promise<void> {
  logInfo(FN, `Sending FCM to topic: ${topic}`);
  try {
    await admin.messaging().send({
      topic,
      notification: { title: payload.title, body: payload.body },
      data: payload.data,
    });
  } catch (err) {
    logError(FN, err);
  }
}
