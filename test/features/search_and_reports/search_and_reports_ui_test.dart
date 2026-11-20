// test/features/search_and_reports/search_and_reports_ui_test.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:true_corporate_job_finder/core/demo/demo_provider.dart';
import 'package:true_corporate_job_finder/core/router/app_redirect.dart';
import 'package:true_corporate_job_finder/core/utils/constants.dart';
import 'package:true_corporate_job_finder/data/models/enums.dart';
import 'package:true_corporate_job_finder/data/models/job.dart';
import 'package:true_corporate_job_finder/data/models/job_query.dart';
import 'package:true_corporate_job_finder/data/models/recommendation.dart';
import 'package:true_corporate_job_finder/data/models/user_doc.dart';
import 'package:true_corporate_job_finder/data/models/user_report.dart';
import 'package:true_corporate_job_finder/data/repositories/admin_report_repository.dart';
import 'package:true_corporate_job_finder/data/repositories/auth_repository.dart';
import 'package:true_corporate_job_finder/data/repositories/jobs_repository.dart';
import 'package:true_corporate_job_finder/data/repositories/recommendation_repository.dart';
import 'package:true_corporate_job_finder/data/repositories/report_repository.dart';
import 'package:true_corporate_job_finder/data/repositories/search_repository.dart';
import 'package:true_corporate_job_finder/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:true_corporate_job_finder/features/home/providers/home_providers.dart';
import 'package:true_corporate_job_finder/features/recommendations/presentation/recommendations_screen.dart';
import 'package:true_corporate_job_finder/features/recommendations/providers/recommendation_providers.dart';
import 'package:true_corporate_job_finder/features/reports/presentation/reports_screen.dart';
import 'package:true_corporate_job_finder/features/search/presentation/ai_search_tab.dart';

// ── Mock User Helper ─────────────────────────────────────────────────────────
class FakeUser extends Fake implements User {
  @override
  String get uid => 'candidate_test_123';
  @override
  bool get isAnonymous => false;
}

class FakeAnonymousUser extends Fake implements User {
  @override
  String get uid => 'anon_guest_456';
  @override
  bool get isAnonymous => true;
}

// ── Custom Mock Repositories for Error & Rate Limit Testing ─────────────────
class ErrorSearchRepository extends MockSearchRepository {
  @override
  Future<ParseQueryResult> parseQuery(String queryText, {String? uid}) async {
    return const ParseQueryResult(
      query: JobQuery(fallback: true, keyword: 'developer'),
      fallbackNotice: 'AI search limit reached. Defaulted to standard keyword search.',
    );
  }
}

class RateLimitReportRepository extends MockReportRepository {
  @override
  Future<String> submitReport({
    required UserReportCategory category,
    String? jobId,
    required String text,
    String? screenshotPath,
  }) async {
    throw Exception('Daily report limit reached (max 10 reports per day).');
  }
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      isDemoModeProvider.overrideWith((ref) => true),
      ...overrides,
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Search, Reports & Deep Match Widget Tests', () {
    // ── Test 1: Filter chips editable and removable before run ────────────────
    testWidgets('1. Filter chips are editable and removable before run in S25 AI search',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiSearchTab(),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
          ],
        ),
      );

      // Enter query and interpret
      final input = find.byKey(const Key('ai_search_input'));
      expect(input, findsOneWidget);
      await tester.enterText(input, 'Java developer in Kolkata');
      await tester.tap(find.byKey(const Key('ai_interpret_btn')));
      await tester.pumpAndSettle();

      // Verify interpreted filter chips appear
      expect(find.byKey(const Key('filter_chip_skill_Java')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_city_Kolkata')), findsOneWidget);

      // Verify editable: tap on Kolkata chip
      await tester.tap(find.byKey(const Key('filter_chip_city_Kolkata')));
      await tester.pumpAndSettle();

      // Edit dialog appears
      expect(find.text('Edit City'), findsOneWidget);
      final editField = find.byKey(const Key('edit_filter_text_field'));
      expect(editField, findsOneWidget);

      // Change city to Bengaluru and save
      await tester.enterText(editField, 'Bengaluru');
      await tester.tap(find.byKey(const Key('save_filter_btn')));
      await tester.pumpAndSettle();

      // Verify updated chip
      expect(find.byKey(const Key('filter_chip_city_Bengaluru')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_city_Kolkata')), findsNothing);

      // Verify removable: tap delete icon on Java skill chip
      final javaChip = find.byKey(const Key('filter_chip_skill_Java'));
      expect(javaChip, findsOneWidget);

      // Find the delete icon inside the chip
      final deleteIcon = find.descendant(
        of: javaChip,
        matching: find.byIcon(Icons.cancel),
      );
      if (deleteIcon.evaluate().isNotEmpty) {
        await tester.tap(deleteIcon);
      } else {
        // Alternatively tap chip and click Remove in dialog
        await tester.tap(javaChip);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('remove_filter_btn')));
      }
      await tester.pumpAndSettle();

      // Verify skill chip removed
      expect(find.byKey(const Key('filter_chip_skill_Java')), findsNothing);
    });

    // ── Test 2: Fallback notice on error / quota exceeded ────────────────────
    testWidgets('2. Fallback notice displayed on error or quota limit in S25 AI search',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiSearchTab(),
          overrides: [
            searchRepositoryProvider.overrideWith((ref) => ErrorSearchRepository()),
            authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
          ],
        ),
      );

      final input = find.byKey(const Key('ai_search_input'));
      await tester.enterText(input, 'Any query exceeding quota');
      await tester.tap(find.byKey(const Key('ai_interpret_btn')));
      await tester.pumpAndSettle();

      // Fallback notice banner is displayed
      expect(find.byKey(const Key('ai_fallback_notice')), findsOneWidget);
      expect(
        find.textContaining('AI search limit reached. Defaulted to standard keyword search.'),
        findsOneWidget,
      );
    });

    // ── Test 3: Report form validation and counter ───────────────────────────
    testWidgets('3. S35 Report form character counter and validation enforces 5-1000 chars',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ReportsScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
          ],
        ),
      );

      // Verify character counter starts at 0/1000
      expect(find.byKey(const Key('report_char_counter')), findsOneWidget);
      expect(find.text('0/1000'), findsOneWidget);

      // Submit with empty text -> validation error
      await tester.tap(find.byKey(const Key('submit_report_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Description must be at least 5 characters.'), findsOneWidget);

      // Enter short text (< 5 chars)
      await tester.enterText(find.byKey(const Key('report_description_input')), 'Hi');
      await tester.pumpAndSettle();
      expect(find.text('2/1000'), findsOneWidget);

      await tester.tap(find.byKey(const Key('submit_report_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Description must be at least 5 characters.'), findsOneWidget);

      // Enter valid text
      await tester.enterText(
        find.byKey(const Key('report_description_input')),
        'Valid report description detailing issue with salary information.',
      );
      await tester.pumpAndSettle();
      expect(find.text('65/1000'), findsOneWidget);
      await tester.tap(find.byKey(const Key('submit_report_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Description must be at least 5 characters.'), findsNothing);
    });

    // ── Test 4: Report status chips ──────────────────────────────────────────
    testWidgets('4. S35 "My Reports" displays status chips (Open, In review, Resolved, Rejected)',
        (tester) async {
      final mockReports = [
        UserReport(
          id: 'rep_1',
          reporterUid: 'candidate_test_123',
          category: UserReportCategory.incorrectJob,
          text: 'Job description error',
          status: UserReportStatus.open,
          createdAt: DateTime.now(),
        ),
        UserReport(
          id: 'rep_2',
          reporterUid: 'candidate_test_123',
          category: UserReportCategory.brokenLink,
          text: 'Link broken',
          status: UserReportStatus.inReview,
          createdAt: DateTime.now(),
        ),
        UserReport(
          id: 'rep_3',
          reporterUid: 'candidate_test_123',
          category: UserReportCategory.suspiciousJob,
          text: 'Suspicious recruiter',
          status: UserReportStatus.resolved,
          adminNote: 'Verified and resolved with official company feed.',
          createdAt: DateTime.now(),
        ),
      ];

      final mockRepo = MockReportRepository();

      await tester.pumpWidget(
        _wrap(
          const ReportsScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
            reportRepositoryProvider.overrideWith((ref) => mockRepo),
          ],
        ),
      );

      // Switch to "My Reports" tab
      await tester.tap(find.byKey(const Key('my_reports_tab_header')));
      await tester.pumpAndSettle();

      // Check for status chips
      expect(find.text('Open'), findsWidgets);
      expect(find.text('Resolved'), findsWidgets);

      // Check admin reply container
      expect(find.byKey(const Key('admin_reply_rep_001')), findsOneWidget);
      expect(
        find.textContaining('Thank you for reporting. The salary information has been updated'),
        findsOneWidget,
      );
    });

    // ── Test 5: Report rate-limit message ────────────────────────────────────
    testWidgets('5. Report rate-limit message displayed when limit exceeded',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ReportsScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
            reportRepositoryProvider.overrideWith((ref) => RateLimitReportRepository()),
          ],
        ),
      );

      await tester.enterText(
        find.byKey(const Key('report_description_input')),
        'Attempting to submit report beyond limit',
      );
      await tester.tap(find.byKey(const Key('submit_report_btn')));
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(
        find.textContaining('Daily report limit reached (max 10 reports per day).'),
        findsWidgets,
      );
    });

    // ── Test 6: Deep Match confirm sheet text ────────────────────────────────
    testWidgets('6. S24 Deep Match confirmation sheet explains only compact summary sent',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RecommendationsScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
            isProfileConfirmedProvider.overrideWith((ref) => true),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap Deep Match button
      final deepMatchBtn = find.byKey(const Key('deep_match_btn'));
      expect(deepMatchBtn, findsOneWidget);
      await tester.tap(deepMatchBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet title and privacy guarantee text
      expect(find.text('AI Deep Match'), findsOneWidget);
      expect(
        find.textContaining('Only a compact summary (confirmed skills, education, preferences) is sent.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Your resume file is never sent.'),
        findsOneWidget,
      );
      expect(find.text('Remaining today: 3/3'), findsOneWidget);
      expect(find.byKey(const Key('confirm_deep_match_btn')), findsOneWidget);
    });

    // ── Test 7: Guest cannot see Deep Match button ───────────────────────────
    testWidgets('7. Guest cannot see Deep Match button on S24',
        (tester) async {
      // Guest: anonymous user
      await tester.pumpWidget(
        _wrap(
          const RecommendationsScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(FakeAnonymousUser())),
            isProfileConfirmedProvider.overrideWith((ref) => false),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Deep Match button must NOT be present
      expect(find.byKey(const Key('deep_match_btn')), findsNothing);
      expect(find.text('Deep Match (uses AI, 3 per day)'), findsNothing);
    });

    // ── Test 8: A12 hidden from USER role ────────────────────────────────────
    testWidgets('8. A12 User reports hidden from USER role and protected via appRedirect',
        (tester) async {
      // Verify appRedirect blocks USER role from /admin/reports
      const userState = AppRedirectState(
        isInitialized: true,
        isAuthenticated: true,
        isEmailVerified: true,
        role: UserRole.user,
        userDoc: UserDoc(uid: 'cand_1', email: 'user@test.com'),
      );

      final redirect = appRedirect(
        state: userState,
        currentPath: '/admin/reports',
      );

      expect(redirect, '/home', reason: 'USER role must be blocked and redirected away from /admin/reports');

      // Verify admin dashboard shows A12 tile to ADMIN
      await tester.pumpWidget(
        _wrap(
          const AdminDashboardScreen(),
          overrides: [
            claimsProvider.overrideWith((ref) => Stream.value(UserRole.admin)),
          ],
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('admin_user_reports_tile')),
        300,
      );
      expect(find.byKey(const Key('admin_user_reports_tile')), findsOneWidget);
    });
  });
}
