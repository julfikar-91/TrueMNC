// test/features/profile/profile_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:true_corporate_job_finder/data/models/enums.dart';
import 'package:true_corporate_job_finder/data/models/field_value_wrapper.dart';
import 'package:true_corporate_job_finder/data/models/resume_model.dart';
import 'package:true_corporate_job_finder/data/repositories/resume_repository.dart';
import 'package:true_corporate_job_finder/features/profile/presentation/profile_preview_screen.dart';

void main() {
  ParsedResumeDraft createTestDraft({
    Provenance nameProvenance = Provenance.explicit,
    Provenance phoneProvenance = Provenance.inferred,
    bool includeExperience = false,
  }) {
    return ParsedResumeDraft(
      resumeId: 'draft_101',
      uid: 'user_101',
      status: 'PARSED',
      warnings: const [],
      personal: PersonalDraft(
        name: FieldValueWrapper<String>(
          value: 'John Doe',
          provenance: nameProvenance,
          confidence: 1.0,
        ),
        email: const FieldValueWrapper<String>(
          value: 'john@example.com',
          provenance: Provenance.explicit,
          confidence: 1.0,
        ),
        phone: FieldValueWrapper<String>(
          value: '+919876543210',
          provenance: phoneProvenance,
          confidence: 0.8,
        ),
        location: const FieldValueWrapper<String>(
          value: 'Bangalore',
          provenance: Provenance.explicit,
          confidence: 1.0,
        ),
        linkedin: const FieldValueWrapper<String>(
          value: null,
          provenance: Provenance.missing,
          confidence: 1.0,
        ),
        github: const FieldValueWrapper<String>(
          value: null,
          provenance: Provenance.missing,
          confidence: 1.0,
        ),
        portfolio: const FieldValueWrapper<String>(
          value: null,
          provenance: Provenance.missing,
          confidence: 1.0,
        ),
      ),
      education: const [
        EducationItemDraft(
          degree: FieldValueWrapper<String>(
            value: 'B.Tech',
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
          specialization: FieldValueWrapper<String>(
            value: 'Computer Science',
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
          institution: FieldValueWrapper<String>(
            value: 'IIT Madras',
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
          graduationYear: FieldValueWrapper<Object>(
            value: 2022,
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
          gradValue: FieldValueWrapper<Object>(
            value: 8.9,
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
          gradScale: FieldValueWrapper<Object>(
            value: 10,
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
          level: FieldValueWrapper<String>(
            value: 'BACHELORS',
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
        ),
      ],
      skills: const SkillsDraft(
        languages: [
          FieldValueWrapper<String>(
            value: 'Dart',
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
          FieldValueWrapper<String>(
            value: 'TypeScript',
            provenance: Provenance.explicit,
            confidence: 1.0,
          ),
        ],
      ),
      experience: ExperienceSectionDraft(
        totalExperienceStated: const FieldValueWrapper<Object>(
          value: null,
          provenance: Provenance.missing,
          confidence: 1.0,
        ),
        items: includeExperience
            ? const [
                ExperienceItemDraft(
                  company: FieldValueWrapper<String>(
                    value: 'Acme Corp',
                    provenance: Provenance.explicit,
                    confidence: 1.0,
                  ),
                  title: FieldValueWrapper<String>(
                    value: 'Software Engineer',
                    provenance: Provenance.explicit,
                    confidence: 1.0,
                  ),
                  location: FieldValueWrapper<String>(
                    value: 'Bangalore',
                    provenance: Provenance.explicit,
                    confidence: 1.0,
                  ),
                  startDate: FieldValueWrapper<String>(
                    value: '2022-01',
                    provenance: Provenance.explicit,
                    confidence: 1.0,
                  ),
                  endDate: FieldValueWrapper<String>(
                    value: 'Present',
                    provenance: Provenance.explicit,
                    confidence: 1.0,
                  ),
                  isCurrent: FieldValueWrapper<bool>(
                    value: true,
                    provenance: Provenance.explicit,
                    confidence: 1.0,
                  ),
                  description: FieldValueWrapper<String>(
                    value: 'Building cross-platform apps',
                    provenance: Provenance.explicit,
                    confidence: 1.0,
                  ),
                ),
              ]
            : const [],
      ),
      summary: const FieldValueWrapper<String>(
        value: 'Passionate developer',
        provenance: Provenance.explicit,
        confidence: 1.0,
      ),
    );
  }

  group('Profile Preview Provenance Badges (S11)', () {
    testWidgets('renders badges per provenance: Extracted, Needs confirmation, Missing',
        (tester) async {
      final draft = createTestDraft(
        nameProvenance: Provenance.explicit,
        phoneProvenance: Provenance.inferred,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchResumeParseProvider('draft_101').overrideWith(
              (ref) => Stream.value(draft),
            ),
          ],
          child: const MaterialApp(
            home: ProfilePreviewScreen(resumeId: 'draft_101'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top banner
      expect(
        find.text('Please review your AI-generated profile before continuing.'),
        findsOneWidget,
      );

      // Provenance badge tests
      expect(find.text('Extracted'), findsWidgets);
      expect(find.text('Needs confirmation'), findsOneWidget); // For phone
      expect(find.text('Missing'), findsWidgets); // For LinkedIn/GitHub
    });

    testWidgets('inferred values are highlighted and accept button marks them confirmed',
        (tester) async {
      final draft = createTestDraft(phoneProvenance: Provenance.inferred);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchResumeParseProvider('draft_101').overrideWith(
              (ref) => Stream.value(draft),
            ),
          ],
          child: const MaterialApp(
            home: ProfilePreviewScreen(resumeId: 'draft_101'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Accept button tooltip
      final acceptButton = find.byTooltip('Accept inferred value');
      expect(acceptButton, findsOneWidget);

      // Tap accept button
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();

      // Accept button should disappear once accepted
      expect(find.byTooltip('Accept inferred value'), findsNothing);
    });

    testWidgets('never auto-selects fresher when work experience is empty',
        (tester) async {
      final draft = createTestDraft(includeExperience: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchResumeParseProvider('draft_101').overrideWith(
              (ref) => Stream.value(draft),
            ),
          ],
          child: const MaterialApp(
            home: ProfilePreviewScreen(resumeId: 'draft_101'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Question must be asked
      expect(find.text('Do you have work experience?'), findsOneWidget);
      expect(find.text('I am a Fresher'), findsOneWidget);
      expect(find.text('I have Experience'), findsOneWidget);

      // Both ChoiceChips must NOT be pre-selected
      final fresherChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'I am a Fresher'),
      );
      final expChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'I have Experience'),
      );

      expect(fresherChip.selected, false);
      expect(expChip.selected, false);

      // Attempting to confirm without answering shows error message
      await tester.tap(find.text('Confirm Profile'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please specify if you have work experience or are a fresher.'),
        findsOneWidget,
      );

      // Scroll to ChoiceChip and select "I am a Fresher"
      await tester.scrollUntilVisible(
        find.text('I am a Fresher'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I am a Fresher'));
      await tester.pumpAndSettle();

      final updatedFresherChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'I am a Fresher'),
      );
      expect(updatedFresherChip.selected, true);
    });
  });
}
