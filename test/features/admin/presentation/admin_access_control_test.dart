// test/features/admin/presentation/admin_access_control_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/core/router/app_redirect.dart';
import 'package:true_corporate_job_finder/core/utils/constants.dart';
import 'package:true_corporate_job_finder/data/models/user_doc.dart';
import 'package:true_corporate_job_finder/data/repositories/auth_repository.dart';
import 'package:true_corporate_job_finder/features/admin/presentation/admin_dashboard_screen.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Admin Access Control Tests - ADMIN cannot see A15/A17', () {
    testWidgets('ADMIN role cannot see A15 or A17 in AdminDashboardScreen',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminDashboardScreen(),
          overrides: [
            claimsProvider.overrideWith(
              (ref) => Stream.value(UserRole.admin),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Regular admin CAN see Company Directory & Audit Logs
      expect(find.byKey(const Key('admin_companies_tile')), findsOneWidget);
      expect(find.byKey(const Key('admin_audit_logs_tile')), findsOneWidget);

      // Regular admin CANNOT see A15 (Administrator Management)
      expect(find.byKey(const Key('admin_administrators_tile')), findsNothing);
      expect(find.text('Administrator Management'), findsNothing);

      // Regular admin CANNOT see A17 (System Configuration)
      expect(find.byKey(const Key('admin_system_config_tile')), findsNothing);
      expect(find.text('System Configuration'), findsNothing);

      // Also verify header displays 'ADMIN' badge (not SUPER_ADMIN)
      expect(find.text('ADMIN'), findsOneWidget);
    });

    testWidgets('SUPER_ADMIN role CAN see both A15 and A17 in AdminDashboardScreen',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminDashboardScreen(),
          overrides: [
            claimsProvider.overrideWith(
              (ref) => Stream.value(UserRole.superAdmin),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // SUPER_ADMIN can see all operations
      expect(find.byKey(const Key('admin_companies_tile')), findsOneWidget);
      expect(find.byKey(const Key('admin_audit_logs_tile')), findsOneWidget);

      // Scroll to reveal SUPER_ADMIN controls in the ListView
      await tester.scrollUntilVisible(
        find.byKey(const Key('admin_administrators_tile')),
        100,
      );

      // SUPER_ADMIN CAN see A15 (Administrator Management)
      expect(find.byKey(const Key('admin_administrators_tile')), findsOneWidget);
      expect(find.text('Administrator Management'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('admin_system_config_tile')),
        100,
      );

      // SUPER_ADMIN CAN see A17 (System Configuration)
      expect(find.byKey(const Key('admin_system_config_tile')), findsOneWidget);
      expect(find.text('System Configuration'), findsOneWidget);

      // Header and cards display 'SUPER_ADMIN' badge
      expect(find.text('SUPER_ADMIN'), findsWidgets);
    });

    group('Route Guard (appRedirect) enforces SUPER_ADMIN access on A15 & A17', () {
      const defaultUserDoc = UserDoc(
        uid: 'admin_1',
        email: 'admin@company.com',
        onboardingDone: true,
        resumeOnboardingDone: true,
        resumeParseInProgress: false,
        resumeParsed: true,
        profileConfirmed: true,
        preferencesMissing: false,
      );

      test('ADMIN role is redirected to /admin when navigating to A15 (/admin/administrators)', () {
        const state = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          role: UserRole.admin,
          userDoc: defaultUserDoc,
        );

        final redirect = appRedirect(
          state: state,
          currentPath: '/admin/administrators',
        );

        expect(redirect, '/admin',
            reason: 'ADMIN must be blocked from A15 and redirected to /admin');
      });

      test('ADMIN role is redirected to /admin when navigating to A17 (/admin/config)', () {
        const state = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          role: UserRole.admin,
          userDoc: defaultUserDoc,
        );

        final redirect = appRedirect(
          state: state,
          currentPath: '/admin/config',
        );

        expect(redirect, '/admin',
            reason: 'ADMIN must be blocked from A17 and redirected to /admin');
      });

      test('SUPER_ADMIN role is ALLOWED to access A15 and A17', () {
        const state = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          role: UserRole.superAdmin,
          userDoc: defaultUserDoc,
        );

        expect(
          appRedirect(state: state, currentPath: '/admin/administrators'),
          isNull,
          reason: 'SUPER_ADMIN is permitted on A15',
        );

        expect(
          appRedirect(state: state, currentPath: '/admin/config'),
          isNull,
          reason: 'SUPER_ADMIN is permitted on A17',
        );
      });
    });
  });
}
