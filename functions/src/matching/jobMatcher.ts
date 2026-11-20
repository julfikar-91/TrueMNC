// functions/src/matching/jobMatcher.ts
// Deterministic job-candidate matching logic (server-side).
// Pure TypeScript matching engine — NO Gemini calls.
import { db, Collections } from "../utils/config";
import { logInfo } from "../utils/logger";
import { scoreForUser, CandidateProfile, JobMatchCriteria } from "./score";

const FN = "jobMatcher";

export async function matchJobToUser(
  jobId: string,
  userId: string,
): Promise<number> {
  logInfo(FN, "Matching job to user deterministically", { jobId, userId });

  // Fetch job and user profile
  const [jobSnap, userSnap, skillsSnap] = await Promise.all([
    db().collection(Collections.JOBS).doc(jobId).get(),
    db().collection(Collections.USERS).doc(userId).get(),
    db().collection(Collections.USERS).doc(userId).collection("skills").doc("canonical").get(),
  ]);

  if (!jobSnap.exists || !userSnap.exists) return 0;
  const jobData = { id: jobSnap.id, ...jobSnap.data() } as JobMatchCriteria;
  const userData = userSnap.data() || {};
  const skillsData = skillsSnap.exists ? skillsSnap.data() : null;

  const profile: CandidateProfile = {
    location: userData.location,
    skills: skillsData?.canonicalList || userData.matchKeys || [],
    profile_confirmed: userData.profile_confirmed,
  };

  const result = scoreForUser(profile, userData.preferences, jobData);
  return result.score;
}
