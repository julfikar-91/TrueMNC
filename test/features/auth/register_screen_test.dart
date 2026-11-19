// test/features/auth/register_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:true_corporate_job_finder/core/router/app_router.dart';
import 'package:true_corporate_job_finder/core/widgets/app_button.dart';
import 'package:true_corporate_job_finder/features/auth/presentation/register_screen.dart';
import 'package:true_corporate_job_finder/features/auth/providers/auth_providers.dart';

class MockAuthNotifier extends AuthNotifier {
  bool signUpCalled = false;
  String? lastEmail;

  @override
  Future<void> build() async {}

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    signUpCalled = true;
    lastEmail = email;
    state = const AsyncData(null);
  }
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const Scaffold(body: Text('Verify Email')),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const Scaffold(body: Text('Login')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  group('S04 RegisterScreen Form Validation', () {
    testWidgets('shows validation errors when submitting completely empty form',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      // Tap Create Account without typing anything
      await tester.tap(find.widgetWithText(AppButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Expect inline error messages
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email address is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(
        find.text('You must accept the terms and privacy policy.'),
        findsOneWidget,
      );
    });

    testWidgets('validates malformed email', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const RegisterScreen()));

      // Enter name and invalid email
      final nameField = find.widgetWithText(TextFormField, 'Full Name');
      final emailField =
          find.widgetWithText(TextFormField, 'Corporate / Primary Email');

      await tester.enterText(nameField, 'Jane Doe');
      await tester.enterText(emailField, 'notanemail');

      await tester.tap(find.widgetWithText(AppButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('validates password strength policy and mismatch',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const RegisterScreen()));

      final passwordField = find.widgetWithText(TextFormField, 'Password');
      final confirmField =
          find.widgetWithText(TextFormField, 'Confirm Password');

      // Short password
      await tester.enterText(passwordField, 'short');
      await tester.enterText(confirmField, 'mismatch');

      await tester.tap(find.widgetWithText(AppButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 8 characters long'),
        findsOneWidget,
      );
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('validates terms checkbox requirement', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const RegisterScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'Alex Morgan');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Corporate / Primary Email'),
          'alex@corporation.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'CorporatePass2026');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'CorporatePass2026');

      // Leave terms unchecked and submit
      await tester.tap(find.widgetWithText(AppButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text('You must accept the terms and privacy policy.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'successfully triggers signUp when all fields are valid and terms accepted',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockNotifier = MockAuthNotifier();

      await tester.pumpWidget(
        _wrap(
          const RegisterScreen(),
          overrides: [
            authNotifierProvider.overrideWith(() => mockNotifier),
          ],
        ),
      );

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'Alex Morgan');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Corporate / Primary Email'),
          'alex@corporation.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'CorporatePass2026');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'CorporatePass2026');

      // Check terms checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(mockNotifier.signUpCalled, isTrue);
      expect(mockNotifier.lastEmail, 'alex@corporation.com');
      expect(find.text('Verify Email'), findsOneWidget);
    });
  });
}
