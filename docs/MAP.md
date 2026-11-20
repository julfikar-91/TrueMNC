# Project Interface Map

## Repositories & Methods
- `JobsRepository`: `recentlyAdded({pageSize, startAfter})`, `byTypeAndCategory(...)`, `byCity(...)`, `byCompany(...)`, `getById(jobId)`, `queryJobs(query, {pageSize, startAfter})`
- `RecommendationRepository`: `watchRecommendations(uid, {limit})`, `watchSkillMatches(...)`, `watchEducationMatches(...)`, `watchLocationMatches(...)`, `scoreForUser(jobId)`, `refreshRecommendations()`, `getRemainingDeepMatches(uid)`, `triggerDeepMatch()`
- `ReportRepository`: `submitReport({category, jobId, text, screenshotPath})`, `watchMyReports(uid)`, `uploadScreenshot(uid, bytes, ext)`
- `AdminReportRepository`: `getPagedReports({status, pageSize, startAfter})`, `updateReportStatus({reportId, status, adminNote})`
- `SearchRepository`: `getRemainingAiQuota(uid)`, `parseQuery(queryText, {uid})`
- `ResumeRepository`: `uploadResume(file)`, `watchResume(id)`, `deleteResume(id)`
- `AdminRepository`: `watchStats()`, `watchCompanies()`, `toggleCompanyStatus(id, enabled)`, `upsertScoringConfig(config)`, `rollbackScoringConfig(version)`
- `AuthRepository`: `currentUser`, `signInWithEmailAndPassword(email, pass)`, `registerWithEmailAndPassword(email, pass)`, `signOut()`, `sendPasswordResetEmail(email)`
- `CompanyRepository`: `watchCompanies()`, `getCompanyById(id)`, `watchActiveCompanies()`
- `ProfileRepository`: `watchProfile(uid)`, `confirmProfile(uid, profile)`

## Riverpod Providers
- `jobsRepositoryProvider`: `Provider<JobsRepository>` (`lib/data/repositories/jobs_repository.dart`)
- `recommendationRepositoryProvider`: `Provider<RecommendationRepository>` (`lib/data/repositories/recommendation_repository.dart`)
- `reportRepositoryProvider`: `Provider<ReportRepository>` (`lib/data/repositories/report_repository.dart`)
- `adminReportRepositoryProvider`: `Provider<AdminReportRepository>` (`lib/data/repositories/admin_report_repository.dart`)
- `searchRepositoryProvider`: `Provider<SearchRepository>` (`lib/data/repositories/search_repository.dart`)
- `authRepositoryProvider`: `Provider<AuthRepository>` (`lib/data/repositories/auth_repository.dart`)
- `authStateProvider`: `StreamProvider<User?>` (`lib/data/repositories/auth_repository.dart`)
- `claimsProvider`: `StreamProvider<UserRole>` (`lib/data/repositories/auth_repository.dart`)
- `userDocProvider`: `StreamProvider<UserDoc?>` (`lib/data/repositories/auth_repository.dart`)
- `topRecommendationsProvider`: `AutoDisposeStreamProvider<List<Recommendation>>` (`lib/features/recommendations/providers/recommendation_providers.dart`)

## Cloud Functions Callables
- `parseResume`: input `{ storagePath }`, errors `unauthenticated`, `invalid-argument`, `resource-exhausted` (`functions/src/callables/parseResume.ts`)
- `confirmProfile`: input `{ resumeId, profile }`, errors `unauthenticated`, `permission-denied` (`functions/src/callables/confirmProfile.ts`)
- `scoreForUser`: input `{ jobId }`, errors `unauthenticated`, `not-found` (`functions/src/callables/scoreForUser.ts`)
- `refreshRecommendations`: input `{}`, errors `unauthenticated`, `resource-exhausted` (`functions/src/callables/refreshRecommendations.ts`)
- `parseSearchQuery`: input `{ query }`, errors `unauthenticated`, `invalid-argument` (`functions/src/callables/parseSearchQuery.ts`)
- `submitReport`: input `{ category, jobId?, text, screenshotPath? }`, errors `unauthenticated`, `resource-exhausted`, `not-found` (`functions/src/callables/submitReport.ts`)
- `adminUpdateReport`: input `{ reportId, status, adminNote? }`, errors `unauthenticated`, `permission-denied`, `not-found` (`functions/src/callables/adminUpdateReport.ts`)
- `deepMatch`: input `{}`, errors `unauthenticated`, `resource-exhausted` (`functions/src/callables/deepMatch.ts`)
- `deleteAccount`: input `{}`, errors `unauthenticated`, `failed-precondition (REAUTH_REQUIRED)` (`functions/src/callables/deleteAccount.ts`)

## Firestore Collections & Writers
- `jobs`: `collectionPipeline.ts`, `adminJobActions.ts`, `onReportCreated.ts`
- `companies`: `seedAll.ts`, `companyActions.ts`, `AdminRepository`
- `users`: `AuthRepository`, `confirmProfile.ts`, `saveCareerPreferences.ts`, `deleteAccount.ts (deletion)`
- `users/{uid}/recommendations`: `scoreForUser.ts`, `fanout.ts`, `deepMatch.ts`
- `reports`: `submitReport.ts`, `adminUpdateReport.ts`
- `auditLogs`: `writeAudit` in `functions/src/utils/audit.ts`
- `config`: `seedConfig.ts`, `systemConfigActions.ts`

## Router & Routes
- `lib/core/router/app_router.dart`: `AppRoutes` constants and `GoRouter` routes list
- Guard: `appRedirect` in `lib/core/router/app_redirect.dart`

## Shared Widgets
- `JobCard`: `lib/features/jobs/presentation/widgets/job_card.dart`
- `MatchBadge`: `lib/features/jobs/presentation/widgets/match_badge.dart`
- `VerificationBadge`: `lib/features/jobs/presentation/widgets/verification_badge.dart`
- `StatusChip`: `lib/features/jobs/presentation/widgets/status_chip.dart`
- `SectionHeader`: `lib/features/jobs/presentation/widgets/section_header.dart`
- `EmptyStateWidget`: `lib/core/widgets/empty_state_widget.dart`
- `SkeletonList`: `lib/core/widgets/skeleton_list.dart`

## Config Keys
- `config/app`: `minAppVersion`, `aiModels.geminiParserModel`, `maintenanceMode`, `features.allowDeepMatch`, `caps.dailyNotificationsMax`
- `config/scoring_v{n}`: `weights{skills,education,experience,location,preference}`, `threshold`, `softCapSkillsCoverage`, `labels`

## Job Adapters
- `LeverAdapter`: `fetchJobs(source)` (`functions/src/adapters/lever.ts`)
- `SmartRecruitersAdapter`: `fetchJobs(source)` (`functions/src/adapters/smartrecruiters.ts`)
