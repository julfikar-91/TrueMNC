// test/core/widgets/password_strength_meter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/core/widgets/password_strength_meter.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void main() {
  group('evaluateStrength unit evaluation', () {
    test('returns empty for empty string', () {
      expect(evaluateStrength(''), PasswordStrength.empty);
    });

    test('returns weak when under 8 characters', () {
      expect(evaluateStrength('Ab1'), PasswordStrength.weak);
      expect(evaluateStrength('Pass1'), PasswordStrength.weak);
    });

    test('returns weak when missing letter or digit', () {
      expect(evaluateStrength('12345678'), PasswordStrength.weak);
      expect(evaluateStrength('abcdefgh'), PasswordStrength.weak);
    });

    test('returns medium when meeting 8 chars + letter + digit', () {
      expect(evaluateStrength('Password1'), PasswordStrength.medium);
      expect(evaluateStrength('Secure99'), PasswordStrength.medium);
    });

    test('returns strong when length >= 12 with special characters', () {
      expect(evaluateStrength('CorporateJobFinder2026!'), PasswordStrength.strong);
      expect(evaluateStrength('Admin#Pass12345'), PasswordStrength.strong);
    });
  });

  group('PasswordStrengthMeter Widget', () {
    testWidgets('renders nothing (SizedBox.shrink) when password is empty', (tester) async {
      await tester.pumpWidget(_wrap(const PasswordStrengthMeter(password: '')));
      expect(find.text('Weak'), findsNothing);
      expect(find.text('Medium'), findsNothing);
      expect(find.text('Strong'), findsNothing);
    });

    testWidgets('displays Weak label and hint when password is weak', (tester) async {
      await tester.pumpWidget(_wrap(const PasswordStrengthMeter(password: 'short')));
      expect(find.text('Weak'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
    });

    testWidgets('displays Medium label when password meets baseline requirements', (tester) async {
      await tester.pumpWidget(_wrap(const PasswordStrengthMeter(password: 'ValidPass1')));
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsNothing);
    });

    testWidgets('displays Strong label when password is >= 12 chars with special character', (tester) async {
      await tester.pumpWidget(
        _wrap(const PasswordStrengthMeter(password: 'VeryStrongPass2026!')),
      );
      expect(find.text('Strong'), findsOneWidget);
      expect(find.text('Weak'), findsNothing);
      expect(find.text('Medium'), findsNothing);
    });

    testWidgets('has accessible semantic label for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const PasswordStrengthMeter(password: 'Pass1234')));
      expect(
        find.bySemanticsLabel(RegExp(r'Password strength: Medium')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
