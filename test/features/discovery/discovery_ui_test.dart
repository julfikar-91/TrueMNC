// test/features/discovery/discovery_ui_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:true_corporate_job_finder/core/demo/demo_provider.dart';
import 'package:true_corporate_job_finder/data/models/company.dart';
import 'package:true_corporate_job_finder/data/models/enums.dart';
import 'package:true_corporate_job_finder/data/models/job.dart';
import 'package:true_corporate_job_finder/data/models/recommendation.dart';
import 'package:true_corporate_job_finder/data/models/user_doc.dart';
import 'package:true_corporate_job_finder/data/repositories/auth_repository.dart';
import 'package:true_corporate_job_finder/data/repositories/recommendation_repository.dart';
import 'package:true_corporate_job_finder/features/home/presentation/home_screen.dart';
import 'package:true_corporate_job_finder/features/home/providers/home_providers.dart';
import 'package:true_corporate_job_finder/features/jobs/presentation/job_detail_screen.dart';
import 'package:true_corporate_job_finder/features/jobs/presentation/widgets/job_match_card.dart';
import 'package:true_corporate_job_finder/features/jobs/presentation/widgets/match_badge.dart';
import 'package:true_corporate_job_finder/features/recommendations/providers/recommendation_providers.dart';

// ── Test Mock Repository ─────────────────────────────────────────────────────
class TestRecommendationRepository extends MockRecommendationRepository {
  TestRecommendationRepository({this.rateLimitMessage});

  final String? rateLimitMessage;

  @override
  Future<String?> refreshRecommendations() async {
    return rateLimitMessage ?? 'You can only refresh recommendations once every 5 minutes.';
  }
}

// ── Test Data Helpers ────────────────────────────────────────────────────────
Job createTestJob({
  String id = 'job_test_1',
  String title = 'Junior Java Developer',
  JobStatus status = JobStatus.active,
  String companyName = 'Tata Consultancy Services',
  String applyUrl = 'https://tcs.com/careers/junior-java',
  List<String> locations = const ['Kolkata'],
  List<String> requiredSkills = const ['Java', 'SQL'],
}) {
  return Job(
    id: id,
    companyId: 'comp_tcs_1',
    companyName: companyName,
    title: title,
    description: 'We are seeking a motivated Junior Java Developer.',
    applyUrl: applyUrl,
    status: status,
    locations: locations,
    requiredSkills: requiredSkills,
    verification: const JobVerification(state: VerificationState.verified),
  );
}

const testRecommendation = Recommendation(
  id: 'rec_job_1',
  jobId: 'job_test_1',
  score: 84.0,
  breakdown: ScoreBreakdown(
    skills: 80,
    education: 100,
    experience: 50,
    location: 100,
    preference: 100,
  ),
  matchedSkills: ['Java', 'SQL'],
  missingSkills: ['PostgreSQL'],
  reasons: [
    'Skills strongly match Junior Java Developer requirements',
    'B.Tech CSE satisfies degree requirement',
  ],
  scoreVersion: 'v1',
  isNew: true,
);

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      isDemoModeProvider.overrideWith((ref) => true),
      ...overrides,
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Discovery UI & Recommendation Tests', () {
    // ── 1. MatchBadge text labels (not colour only) ──────────────────────────
    testWidgets('MatchBadge displays text labels alongside percentage (WCAG AA)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              MatchBadge(score: 85),
              MatchBadge(score: 70),
              MatchBadge(score: 58),
              MatchBadge(score: 42),
            ],
          ),
        ),
      );

      // Verify text labels and percent format
      expect(find.text('Strong 85%'), findsOneWidget);
      expect(find.text('Good 70%'), findsOneWidget);
      expect(find.text('Possible 58%'), findsOneWidget);
      expect(find.text('Low 42%'), findsOneWidget);

      // Verify Semantics for accessibility
      expect(
        find.bySemanticsLabel('Match score: Strong, 85%'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Match score: Good, 70%'),
        findsOneWidget,
      );

      handle.dispose();
    });

    // ── 2. Match card shows experience-unknown flag & S12 link ───────────────
    testWidgets(
        'JobMatchCard shows experience-unknown flag, breakdown bars, and disclaimer',
        (tester) async {
      const mockUser = UserDoc(
        uid: 'user_123',
        email: 'candidate@example.com',
        profileConfirmed: true,
      );

      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: JobMatchCard(jobId: 'job_test_1'),
            ),
          ),
          overrides: [
            userDocProvider.overrideWith((ref) => Stream.value(mockUser)),
            jobMatchScoreProvider('job_test_1').overrideWith(
              (ref) => Future.value({
                'score': 84.0,
                'label': 'Strong',
                'breakdown': {
                  'skills': 80.0,
                  'education': 100.0,
                  'experience': 50.0,
                  'location': 100.0,
                  'preference': 100.0,
                },
                'matchedSkills': ['Java', 'SQL'],
                'missingSkills': ['PostgreSQL'],
                'niceToHave': ['Docker'],
                'reasons': ['Skills strongly align with Junior Java Developer'],
                'gaps': ['Missing PostgreSQL knowledge'],
                'flags': ['Add experience for better accuracy'],
                'scoreVersion': 'v1',
              }),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Check Match card title and score
      expect(find.text('Candidate Match'), findsOneWidget);
      expect(find.text('Strong 84%'), findsOneWidget);

      // Check 5-dimension breakdown text
      expect(find.text('Skills (40%)'), findsOneWidget);
      expect(find.text('Education (15%)'), findsOneWidget);
      expect(find.text('Experience (15%)'), findsOneWidget);
      expect(find.text('Location (10%)'), findsOneWidget);
      expect(find.text('Preference (20%)'), findsOneWidget);

      // Check experience unknown flag banner and S12 link
      expect(find.text('Add experience for better accuracy'), findsOneWidget);
      expect(find.text('Add (S12)'), findsOneWidget);

      // Check disclaimer
      expect(
        find.textContaining('Relevance score, not hiring probability'),
        findsOneWidget,
      );
    });

    // ── 3. Guest sees no personalised blocks on Home ─────────────────────────
    testWidgets('Guest sees banner and no personalised blocks on Home dashboard',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeJob = createTestJob();

      await tester.pumpWidget(
        _wrap(
          const HomeScreen(),
          overrides: [
            userDocProvider.overrideWith((ref) => Stream.value(null)),
            isProfileConfirmedProvider.overrideWithValue(false),
            isFresherCandidateProvider.overrideWithValue(false),
            homeTechnicalJobsProvider.overrideWith((ref) => Stream.value([activeJob])),
            homeNonTechnicalJobsProvider.overrideWith((ref) => Stream.value([activeJob])),
            homeRecentlyAddedJobsProvider.overrideWith((ref) => Stream.value([activeJob])),
            homePopularCompaniesProvider.overrideWith(
              (ref) => Stream.value([
                const Company(id: 'c1', name: 'Tata Consultancy Services', isVerified: true),
              ]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Guest banner is visible
      expect(find.byKey(const Key('complete_profile_banner')), findsOneWidget);
      expect(find.text('Complete your profile for personalised jobs'), findsOneWidget);

      // Personalised blocks MUST NOT be rendered
      expect(find.byKey(const Key('section_recommended')), findsNothing);
      expect(find.byKey(const Key('section_best_skills')), findsNothing);
      expect(find.byKey(const Key('section_education')), findsNothing);
      expect(find.byKey(const Key('section_near_location')), findsNothing);
      expect(find.byKey(const Key('section_fresher')), findsNothing);

      // Non-personalised blocks ARE rendered
      expect(find.byKey(const Key('section_technical')), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('section_recently_added')), findsOneWidget);
    });

    // ── 4. Fresher section hidden unless explicitly confirmed ────────────────
    testWidgets('Fresher section is hidden unless user explicitly confirmed fresher status',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      final fresherJob = createTestJob(title: 'Graduate Trainee');

      // Case A: User has NOT confirmed fresher status
      await tester.pumpWidget(
        _wrap(
          const HomeScreen(),
          overrides: [
            isProfileConfirmedProvider.overrideWithValue(true),
            isFresherCandidateProvider.overrideWithValue(false),
            homeTechnicalJobsProvider.overrideWith((ref) => Stream.value([])),
            homeNonTechnicalJobsProvider.overrideWith((ref) => Stream.value([])),
            homeRecentlyAddedJobsProvider.overrideWith((ref) => Stream.value([])),
            homePopularCompaniesProvider.overrideWith((ref) => Stream.value([])),
            homeRecommendedJobsProvider.overrideWith((ref) => Future.value([])),
            homeSkillMatchesProvider.overrideWith((ref) => Future.value([])),
            homeEducationJobsProvider.overrideWith((ref) => Future.value([])),
            homeNearLocationJobsProvider.overrideWith((ref) => Stream.value([])),
            homeFresherJobsProvider.overrideWith((ref) => Stream.value([fresherJob])),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('section_fresher')), findsNothing);
      expect(find.text('Fresher Opportunities'), findsNothing);

      // Case B: User HAS explicitly confirmed fresher status
      await tester.pumpWidget(
        _wrap(
          const HomeScreen(),
          overrides: [
            isProfileConfirmedProvider.overrideWithValue(true),
            isFresherCandidateProvider.overrideWithValue(true),
            homeTechnicalJobsProvider.overrideWith((ref) => Stream.value([])),
            homeNonTechnicalJobsProvider.overrideWith((ref) => Stream.value([])),
            homeRecentlyAddedJobsProvider.overrideWith((ref) => Stream.value([])),
            homePopularCompaniesProvider.overrideWith((ref) => Stream.value([])),
            homeRecommendedJobsProvider.overrideWith((ref) => Future.value([])),
            homeSkillMatchesProvider.overrideWith((ref) => Future.value([])),
            homeEducationJobsProvider.overrideWith((ref) => Future.value([])),
            homeNearLocationJobsProvider.overrideWith((ref) => Stream.value([])),
            homeFresherJobsProvider.overrideWith((ref) => Stream.value([fresherJob])),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('section_fresher')), findsOneWidget);
      expect(find.text('Fresher Opportunities'), findsOneWidget);
    });

    // ── 5. Section hidden when empty on Home ─────────────────────────────────
    testWidgets('Section is completely hidden when its data list is empty',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeJob = createTestJob();

      await tester.pumpWidget(
        _wrap(
          const HomeScreen(),
          overrides: [
            isProfileConfirmedProvider.overrideWithValue(false),
            isFresherCandidateProvider.overrideWithValue(false),
            // Technical has jobs
            homeTechnicalJobsProvider.overrideWith((ref) => Stream.value([activeJob])),
            // Non-Technical is empty
            homeNonTechnicalJobsProvider.overrideWith((ref) => Stream.value([])),
            homeRecentlyAddedJobsProvider.overrideWith((ref) => Stream.value([])),
            homePopularCompaniesProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Technical is visible
      expect(find.byKey(const Key('section_technical')), findsOneWidget);
      expect(find.text('Technical Roles'), findsOneWidget);

      // Non-technical is empty => hidden
      expect(find.byKey(const Key('section_non_technical')), findsNothing);
      expect(find.text('Non-Technical Roles'), findsNothing);
    });

    // ── 6. Refresh recommendations rate-limit message ────────────────────────
    testWidgets('Refresh recommendations displays friendly rate-limit message when throttled',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      const rateLimitMsg = 'You can only refresh recommendations once every 5 minutes.';
      final mockRecRepo = TestRecommendationRepository(rateLimitMessage: rateLimitMsg);

      await tester.pumpWidget(
        _wrap(
          const HomeScreen(),
          overrides: [
            isProfileConfirmedProvider.overrideWithValue(true),
            recommendationRepositoryProvider.overrideWithValue(mockRecRepo),
            homeTechnicalJobsProvider.overrideWith((ref) => Stream.value([])),
            homeNonTechnicalJobsProvider.overrideWith((ref) => Stream.value([])),
            homeRecentlyAddedJobsProvider.overrideWith((ref) => Stream.value([])),
            homePopularCompaniesProvider.overrideWith((ref) => Stream.value([])),
            homeRecommendedJobsProvider.overrideWith((ref) => Future.value([])),
            homeSkillMatchesProvider.overrideWith((ref) => Future.value([])),
            homeEducationJobsProvider.overrideWith((ref) => Future.value([])),
            homeNearLocationJobsProvider.overrideWith((ref) => Stream.value([])),
            homeFresherJobsProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Tap the refresh recommendations button in the AppBar
      final refreshBtn = find.byTooltip('Refresh recommendations');
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      // SnackBar with rate-limit message must appear
      expect(find.text(rateLimitMsg), findsOneWidget);
    });

    // ── 7. Closed job shows no Apply button on JobDetailScreen ────────────────
    testWidgets('Closed job shows Position Closed and hides Apply button',
        (tester) async {
      final closedJob = createTestJob(
        id: 'closed_job_1',
        status: JobStatus.closed,
      );

      await tester.pumpWidget(
        _wrap(
          const JobDetailScreen(jobId: 'closed_job_1'),
          overrides: [
            publicJobProvider('closed_job_1').overrideWith((ref) => Future.value(closedJob)),
            jobMatchScoreProvider('closed_job_1').overrideWith(
              (ref) => Future.value({
                'score': 84.0,
                'label': 'Strong',
                'breakdown': {
                  'skills': 80.0,
                  'education': 100.0,
                  'experience': 50.0,
                  'location': 100.0,
                  'preference': 100.0,
                },
                'matchedSkills': ['Java', 'SQL'],
                'missingSkills': <String>[],
                'niceToHave': <String>[],
                'reasons': <String>[],
                'gaps': <String>[],
                'flags': <String>[],
                'scoreVersion': 'v1',
              }),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Position Closed is displayed
      expect(find.text('Position Closed'), findsOneWidget);

      // Apply button must NOT be present
      expect(find.byKey(const Key('apply_official_btn')), findsNothing);
      expect(find.text('Apply on Official Website'), findsNothing);
    });

    testWidgets('Active job shows Apply on Official Website button',
        (tester) async {
      final activeJob = createTestJob(
        id: 'active_job_1',
        status: JobStatus.active,
      );

      await tester.pumpWidget(
        _wrap(
          const JobDetailScreen(jobId: 'active_job_1'),
          overrides: [
            publicJobProvider('active_job_1').overrideWith((ref) => Future.value(activeJob)),
            jobMatchScoreProvider('active_job_1').overrideWith(
              (ref) => Future.value({
                'score': 84.0,
                'label': 'Strong',
                'breakdown': {
                  'skills': 80.0,
                  'education': 100.0,
                  'experience': 50.0,
                  'location': 100.0,
                  'preference': 100.0,
                },
                'matchedSkills': ['Java', 'SQL'],
                'missingSkills': <String>[],
                'niceToHave': <String>[],
                'reasons': <String>[],
                'gaps': <String>[],
                'flags': <String>[],
                'scoreVersion': 'v1',
              }),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Apply button is present
      expect(find.byKey(const Key('apply_official_btn')), findsOneWidget);
      expect(find.text('Apply on Official Website'), findsOneWidget);
      expect(find.text('Position Closed'), findsNothing);
    });
  });
}
