// test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/core/errors/app_exception.dart';
import 'package:true_corporate_job_finder/features/auth/presentation/login_screen.dart';
import 'package:true_corporate_job_finder/features/auth/providers/auth_providers.dart';

class FailingAuthNotifier extends AuthNotifier {
  int attempts = 0;

  @override
  Future<void> build() async {}

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    attempts++;
    state = AsyncError(
      AuthException.invalidCredentials(),
      StackTrace.current,
    );
  }
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('S05 LoginScreen Anti-Enumeration & Cooldown Behaviour', () {
    testWidgets('shows generic error for invalid credentials', (tester) async {
      final failingNotifier = FailingAuthNotifier();

      await tester.pumpWidget(
        _wrap(
          const LoginScreen(),
          overrides: [
            authNotifierProvider.overrideWith(() => failingNotifier),
          ],
        ),
      );

      final emailField = find.widgetWithText(TextFormField, 'Corporate Email');
      final passField = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(emailField, 'test@corporate.com');
      await tester.enterText(passField, 'ValidPass123');

      // Submit once
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Expect generic error message (anti-enumeration check)
      expect(
        find.text(
          'Invalid email or password. Please check your credentials and try again.',
        ),
        findsOneWidget,
      );
      // Ensure specific enumeration error (like user not found) is NEVER shown
      expect(find.text('User not found'), findsNothing);
      expect(find.text('Wrong password'), findsNothing);
    });

    testWidgets('triggers 30-second cooldown after 5 failed attempts',
        (tester) async {
      final failingNotifier = FailingAuthNotifier();

      await tester.pumpWidget(
        _wrap(
          const LoginScreen(),
          overrides: [
            authNotifierProvider.overrideWith(() => failingNotifier),
          ],
        ),
      );

      final emailField = find.widgetWithText(TextFormField, 'Corporate Email');
      final passField = find.widgetWithText(TextFormField, 'Password');
      final signInButton = find.widgetWithText(FilledButton, 'Sign In');

      await tester.enterText(emailField, 'test@corporate.com');
      await tester.enterText(passField, 'ValidPass123');

      // Trigger 5 consecutive failed attempts
      for (int i = 0; i < 5; i++) {
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
      }

      // After 5 attempts, cooldown banner appears
      expect(
        find.textContaining('Too many failed attempts. Try again in 30 seconds.'),
        findsOneWidget,
      );

      // Button label switches to cooldown text
      expect(find.textContaining('Cooldown (30 s)'), findsOneWidget);

      // Advance clock by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Cooldown (29 s)'), findsOneWidget);
    });
  });
}
