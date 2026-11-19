// test/features/admin/config/system_config_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/features/admin/config/presentation/system_config_screen.dart';
import 'package:true_corporate_job_finder/features/admin/config/providers/system_config_providers.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('A17 System Configuration - Scoring Weights & Save Validation', () {
    testWidgets('total != 100 disables Save button', (tester) async {
      // Provide empty streams so initial state uses defaults:
      // skills=40, education=15, experience=15, location=10, preference=20 => sum = 100
      await tester.pumpWidget(
        _wrap(
          const SystemConfigScreen(),
          overrides: [
            scoringConfigStreamProvider
                .overrideWith((ref) => Stream.value(<String, dynamic>{})),
            appConfigStreamProvider
                .overrideWith((ref) => Stream.value(<String, dynamic>{})),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final saveButtonFinder = find.byKey(const Key('save_config_button'));
      expect(saveButtonFinder, findsOneWidget);

      // 1. Initial State: total == 100 => Enabled
      expect(
        find.text('Weights Total: 100% / 100% (Valid)'),
        findsOneWidget,
      );
      final initialButton = tester.widget<ElevatedButton>(saveButtonFinder);
      expect(initialButton.onPressed, isNotNull,
          reason: 'Save button must be enabled when weights equal 100');

      // 2. Change a slider value to make total != 100
      // Find the first Slider (Skills Weight) and adjust it
      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);

      // Drag the first slider to the left (decreasing skills weight)
      await tester.drag(sliders.first, const Offset(-100, 0));
      await tester.pumpAndSettle();

      // Verify that total is no longer 100 and Save is DISABLED
      final disabledButton = tester.widget<ElevatedButton>(saveButtonFinder);
      expect(disabledButton.onPressed, isNull,
          reason: 'Save button must be disabled when total weights != 100');

      // Verify warning text is displayed
      expect(find.textContaining('Must equal exactly 100%'), findsOneWidget);
      expect(find.text('Save Disabled (Weights != 100%)'), findsOneWidget);
    });
  });
}
