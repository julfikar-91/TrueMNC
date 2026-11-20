// functions/src/index.ts
// Central barrel — export all Gen 2 Cloud Functions.
// Add new function exports here as features are implemented.

import { initAdmin } from "./utils/config";

// Initialise Firebase Admin SDK on cold start
initAdmin();

// ── Callables ─────────────────────────────────────────────────────────────────
export * from "./callables/searchJobs";
export * from "./callables/setUserRole";
export * from "./callables/scoreApplication";
export * from "./callables/updateAppConfig";
export * from "./callables/updateScoringConfig";
export * from "./callables/adminSourceActions";
export * from "./callables/adminJobActions";
export * from "./callables/parseResume";
export * from "./callables/confirmProfile";
export * from "./callables/deleteResume";
export * from "./callables/scoreForUser";
export * from "./callables/refreshRecommendations";
export * from "./callables/saveProfileSection";
export * from "./callables/saveCareerPreferences";
export * from "./callables/applyResumeDiff";
export * from "./callables/parseSearchQuery";
export * from "./callables/submitReport";
export * from "./callables/adminUpdateReport";
export * from "./callables/deepMatch";
export * from "./callables/deleteAccount";

// ── Triggers ──────────────────────────────────────────────────────────────────
export * from "./triggers/onUserCreate";
export * from "./triggers/onApplicationCreate";
export * from "./triggers/onJobUpdate";
export * from "./triggers/onReportCreated";

// ── Scheduled Tasks & Collection Pipeline ─────────────────────────────────────
export * from "./tasks/dailyJobDigest";
export * from "./tasks/collectionPipeline";

// ── Skills, Matching, Rules & Adapters ────────────────────────────────────────
export * from "./matching/skills";
export {
  scoreForUser as computeCandidateMatch,
  checkStage1Eligibility,
  roundScore,
  CandidateProfile,
  CandidateSkill,
  CandidateEducation,
  CandidateExperienceItem,
  JobMatchCriteria,
  MatchResult,
  MatchScoreBreakdown,
} from "./matching/score";
export {
  onJobActivated,
  matchBatch,
  matchBatchTask,
  onProfileConfirmedOrPreferencesChanged,
  onJobStatusChange as handleJobStatusChange,
  pruneRecommendations,
  onJobWriteTrigger,
  getActiveScoringConfig,
  loadUserCandidateData,
} from "./matching/fanout";
export * from "./utils/types";
export * from "./rules/verificationRules";
export * from "./adapters/types";
export * from "./adapters/registry";
export * from "./ai/extractJob";
export * from "./ai/resumeSchema";
export * from "./ai/extractResume";
export * from "./ai/postProcess";
export * from "./ai/parseSearchQuery";
