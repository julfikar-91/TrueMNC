// functions/src/matching/jobMatcher.ts
// Orchestrates job-candidate matching logic (server-side).
import { db, Collections } from "../utils/config";
import { geminiScoreMatch } from "../ai/geminiAdapter";
import { logInfo } from "../utils/logger";

const FN = "jobMatcher";

export async function matchJobToUser(
  jobId: string,
  userId: string,
): Promise<number> {
  logInfo(FN, "Matching job to user", { jobId, userId });

  // Fetch job and resume
  const [jobSnap, userSnap] = await Promise.all([
    db().collection(Collections.JOBS).doc(jobId).get(),
    db().collection(Collections.RESUMES).where("userId", "==", userId).limit(1).get(),
  ]);

  if (!jobSnap.exists) return 0;
  const jobData = jobSnap.data()!;
  const resumeData = userSnap.empty ? null : userSnap.docs[0].data();

  if (!resumeData?.parsedText) return 0;

  const result = await geminiScoreMatch(
    resumeData.parsedText as string,
    jobData["description"] as string,
  );

  return result.score;
}
