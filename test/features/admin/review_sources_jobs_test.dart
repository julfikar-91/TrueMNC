// test/features/admin/review_sources_jobs_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:true_corporate_job_finder/data/models/admin_job.dart';
import 'package:true_corporate_job_finder/data/models/company.dart';
import 'package:true_corporate_job_finder/data/models/company_source.dart';
import 'package:true_corporate_job_finder/data/models/enums.dart';
import 'package:true_corporate_job_finder/data/models/job.dart';
import 'package:true_corporate_job_finder/data/repositories/auth_repository.dart';
import 'package:true_corporate_job_finder/data/repositories/paged_controller.dart';
import 'package:true_corporate_job_finder/features/admin/companies/presentation/company_detail_screen.dart';
import 'package:true_corporate_job_finder/features/admin/jobs/presentation/all_jobs_screen.dart';
import 'package:true_corporate_job_finder/features/admin/review/presentation/review_queue_screen.dart';
import 'package:true_corporate_job_finder/features/admin/sources/presentation/company_sources_screen.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Admin Sources, Jobs & Review Queue Tests', () {
    // ── 1. Review queue soft-lock message ────────────────────────────────────
    testWidgets('Review queue shows soft-lock message when item is claimed by another admin',
        (tester) async {
      final lockedJob = AdminJob(
        job: const Job(
          id: 'job_locked_1',
          companyId: 'comp_1',
          companyName: 'Acme Corp',
          title: 'Senior Flutter Architect',
          description: 'Detailed corporate job description with 100+ characters.',
          applyUrl: 'https://acmecorp.com/apply/1',
          status: JobStatus.pendingReview,
        ),
        reviewReasons: ['R2_DOMAIN_FAILED', 'R7_AI_CONFIDENCE_LOW'],
        reviewClaim: ReviewClaim(
          claimedBy: 'other_admin_uid_456',
          claimedAt: DateTime.now(), // Recent claim within 10 min
        ),
      );

      await tester.pumpWidget(
        _wrap(
          const ReviewQueueScreen(),
          overrides: [
            reviewQueueProvider.overrideWith(
              (ref) => Stream.value([lockedJob]),
            ),
            authStateProvider.overrideWith(
              (ref) => Stream.value(null), // Current user is distinct from other_admin_uid_456
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Verify soft-lock banner is displayed
      expect(find.byKey(const Key('soft_lock_banner')), findsOneWidget);
      expect(
        find.textContaining('Being reviewed by another admin'),
        findsOneWidget,
      );

      // Verify action buttons are disabled when locked
      final approveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('queue_approve_job_locked_1')),
      );
      expect(approveBtn.onPressed, isNull);

      final rejectBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('queue_reject_job_locked_1')),
      );
      expect(rejectBtn.onPressed, isNull);
    });

    // ── 2. Reject requires reason ────────────────────────────────────────────
    testWidgets('Rejecting a job in Review Queue strictly requires a reason',
        (tester) async {
      final unlockedJob = AdminJob(
        job: const Job(
          id: 'job_unlocked_2',
          companyId: 'comp_1',
          companyName: 'Acme Corp',
          title: 'Cloud DevOps Engineer',
          description: 'Detailed description for devops role at acme corp.',
          applyUrl: 'https://acmecorp.com/apply/2',
          status: JobStatus.pendingReview,
        ),
        reviewReasons: ['R8_SAFETY_VIOLATION'],
      );

      await tester.pumpWidget(
        _wrap(
          const ReviewQueueScreen(),
          overrides: [
            reviewQueueProvider.overrideWith(
              (ref) => Stream.value([unlockedJob]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Tap Reject button
      await tester.tap(find.byKey(const Key('queue_reject_job_unlocked_2')));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Reject Job Posting'), findsOneWidget);

      // Tap Confirm without entering reason
      await tester.tap(find.byKey(const Key('confirm_review_reason_btn')));
      await tester.pumpAndSettle();

      // Validation error must appear and dialog must stay open
      expect(find.text('Reason is required (min 3 characters)'), findsOneWidget);
      expect(find.text('Reject Job Posting'), findsOneWidget);

      // Enter valid reason (>= 3 chars) and confirm
      await tester.enterText(
        find.byKey(const Key('review_reason_input')),
        'Suspected scam recruitment wording',
      );
      await tester.pumpAndSettle();

      // Now validation error disappears
      expect(find.text('Reason is required (min 3 characters)'), findsNothing);
    });

    // ── 3. Source enable disabled until verified ─────────────────────────────
    testWidgets('Source enable switch is disabled when company is not verified',
        (tester) async {
      const companyId = 'comp_unverified_1';
      final unverifiedCompany = Company(
        id: companyId,
        name: 'Unverified Startup Inc',
        isVerified: false, // NOT verified
      );

      final testSource = CompanySource(
        id: 'source_1',
        companyId: companyId,
        type: 'GREENHOUSE',
        url: 'https://boards-api.greenhouse.io/v1/boards/startup',
        enabled: false,
        verifiedAt: null, // NOT verified
      );

      await tester.pumpWidget(
        _wrap(
          const CompanySourcesScreen(companyId: companyId),
          overrides: [
            watchCompanyProvider(companyId).overrideWith(
              (ref) => Stream.value(unverifiedCompany),
            ),
            companySourcesProvider(companyId).overrideWith(
              (ref) => Stream.value([testSource]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Find the source switch
      final switchFinder = find.byKey(const Key('source_switch_source_1'));
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      // Switch must be disabled (onChanged == null) because company is unverified
      expect(switchWidget.onChanged, isNull);
    });

    // ── 4. A07 bulk action requires reason ───────────────────────────────────
    testWidgets('A07 Bulk action strictly requires a reason before execution',
        (tester) async {
      final sampleJob = AdminJob(
        job: const Job(
          id: 'job_bulk_1',
          companyId: 'comp_1',
          companyName: 'Acme Corp',
          title: 'Software Engineer',
          description: 'Job description for testing bulk actions.',
          applyUrl: 'https://acmecorp.com/apply/bulk1',
          status: JobStatus.active,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          const AllJobsScreen(),
          overrides: [
            adminJobsPagedControllerProvider.overrideWith(
              (ref) => PagedController<AdminJob>(
                (_) async => PagedResult<AdminJob>(
                  items: [sampleJob],
                  hasMore: false,
                ),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Enter bulk mode
      await tester.tap(find.byTooltip('Bulk Actions'));
      await tester.pumpAndSettle();

      // Select the job
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Tap Bulk Reject button
      await tester.tap(find.byKey(const Key('bulk_reject_btn')));
      await tester.pumpAndSettle();

      // Verify reason dialog appears
      expect(find.text('Bulk REJECT (1 jobs)'), findsOneWidget);

      // Tap Confirm without entering reason
      await tester.tap(find.byKey(const Key('confirm_bulk_action_btn')));
      await tester.pumpAndSettle();

      // Validation error must appear and dialog must stay open
      expect(find.text('Reason is required (min 3 characters)'), findsOneWidget);
      expect(find.text('Bulk REJECT (1 jobs)'), findsOneWidget);
    });
  });
}
