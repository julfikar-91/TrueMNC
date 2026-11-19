// test/core/widgets/app_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/core/widgets/app_button.dart';
import 'package:true_corporate_job_finder/core/widgets/app_text_field.dart';
import 'package:true_corporate_job_finder/core/widgets/error_state_widget.dart';
import 'package:true_corporate_job_finder/core/widgets/offline_chip.dart';

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
  group('AppButton', () {
    testWidgets('enforces min 48dp height for primary button', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Submit', onPressed: () {})),
      );
      final size = tester.getSize(find.byType(AppButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true and ignores tap', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Submit',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);

      await tester.tap(find.byType(AppButton));
      expect(pressed, isFalse);
    });
  });

  group('AppTextField', () {
    testWidgets('toggles obscure text visibility when suffix icon is tapped', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppTextField(
            label: 'Password',
            obscureText: true,
          ),
        ),
      );

      final textFieldFinder = find.byType(EditableText);
      EditableText editable = tester.widget(textFieldFinder);
      expect(editable.obscureText, isTrue);

      // Tap toggle button
      final toggleFinder = find.byTooltip('Show password');
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      editable = tester.widget(textFieldFinder);
      expect(editable.obscureText, isFalse);
    });
  });

  group('ErrorStateWidget', () {
    testWidgets('displays title, message, and triggers onRetry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          ErrorStateWidget(
            title: 'Failed to load',
            message: 'Unable to reach the server',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Unable to reach the server'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });
  });

  group('OfflineChip', () {
    testWidgets('displays offline label and enforces minimum 48dp touch target', (tester) async {
      await tester.pumpWidget(
        _wrap(OfflineChip(onTap: () {})),
      );

      expect(find.text('Offline Mode'), findsOneWidget);
      final size = tester.getSize(find.byType(OfflineChip));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
