// test/features/resume/resume_screens_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:true_corporate_job_finder/data/models/resume_model.dart';
import 'package:true_corporate_job_finder/data/repositories/resume_repository.dart';
import 'package:true_corporate_job_finder/data/services/resume_file_picker_service.dart';
import 'package:true_corporate_job_finder/features/resume/presentation/resume_processing_screen.dart';
import 'package:true_corporate_job_finder/features/resume/presentation/resume_upload_screen.dart';

class FakeResumeFilePickerService implements ResumeFilePickerService {
  FakeResumeFilePickerService({this.fileToReturn});

  SelectedResumeFile? fileToReturn;

  @override
  Future<SelectedResumeFile?> pickResumeFile() async {
    return fileToReturn;
  }
}

void main() {
  group('Resume Upload Validation Tests (S09)', () {
    testWidgets('shows validation error when file extension is not PDF or DOCX',
        (tester) async {
      final fakePicker = FakeResumeFilePickerService(
        fileToReturn: SelectedResumeFile(
          name: 'malicious.exe',
          bytes: Uint8List.fromList([0x4d, 0x5a, 0x00]),
          size: 1024,
          extension: 'exe',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumeFilePickerServiceProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(
            home: ResumeUploadScreen(),
          ),
        ),
      );

      expect(find.text('Tap to select your resume'), findsOneWidget);

      // Tap picker area
      await tester.tap(find.text('Tap to select your resume'));
      await tester.pumpAndSettle();

      // Verify validation error
      expect(
        find.text('Invalid file type. Only PDF and DOCX documents are supported.'),
        findsOneWidget,
      );
      // Continue button should NOT appear
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('shows validation error when file size exceeds 5 MB',
        (tester) async {
      final fakePicker = FakeResumeFilePickerService(
        fileToReturn: SelectedResumeFile(
          name: 'giant_resume.pdf',
          bytes: Uint8List(100),
          size: 6 * 1024 * 1024, // 6 MB
          extension: 'pdf',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumeFilePickerServiceProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(
            home: ResumeUploadScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Tap to select your resume'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('File exceeds maximum limit of 5 MB'),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('displays selected file card and Continue button for valid PDF',
        (tester) async {
      final fakePicker = FakeResumeFilePickerService(
        fileToReturn: SelectedResumeFile(
          name: 'my_resume.pdf',
          bytes: Uint8List(2048),
          size: 2048,
          extension: 'pdf',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumeFilePickerServiceProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(
            home: ResumeUploadScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Tap to select your resume'));
      await tester.pumpAndSettle();

      // Card details
      expect(find.text('my_resume.pdf'), findsOneWidget);
      expect(find.text('PDF • 2.0 KB'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('Resume Processing State Tests (S10)', () {
    testWidgets('FAILED_UNREADABLE state never shows success and displays 3 action options',
        (tester) async {
      const failedResume = ResumeDoc(
        id: 'res_failed_123',
        uid: 'user_456',
        storagePath: 'resumes/user_456/res_failed_123.pdf',
        status: ResumeDocStatus.failedUnreadable,
        progress: ResumeProgressStage.reading,
        errorCode: 'RESUME_UNREADABLE',
        errorMessage: 'Password-protected or encrypted PDFs are not supported.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchResumeProvider('res_failed_123').overrideWith(
              (ref) => Stream.value(failedResume),
            ),
          ],
          child: const MaterialApp(
            home: ResumeProcessingScreen(resumeId: 'res_failed_123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Must display Extraction Failed, never success
      expect(find.text('Extraction Failed'), findsOneWidget);
      expect(
        find.text('Password-protected or encrypted PDFs are not supported.'),
        findsOneWidget,
      );

      // Must provide 3 fallback options
      expect(find.text('Retry Extraction'), findsOneWidget);
      expect(find.text('Replace Resume File'), findsOneWidget);
      expect(find.text('Create Profile Manually'), findsOneWidget);

      // Verify no success or review widgets are visible
      expect(find.text('Please review your AI-generated profile'), findsNothing);
    });

    testWidgets('FAILED_AI state displays AI error and retry actions',
        (tester) async {
      const failedAiResume = ResumeDoc(
        id: 'res_ai_fail',
        uid: 'user_456',
        storagePath: 'resumes/user_456/res_ai_fail.pdf',
        status: ResumeDocStatus.failedAi,
        progress: ResumeProgressStage.creating,
        errorCode: 'AI_INVALID',
        errorMessage: 'Extracted data does not match resume schema.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchResumeProvider('res_ai_fail').overrideWith(
              (ref) => Stream.value(failedAiResume),
            ),
          ],
          child: const MaterialApp(
            home: ResumeProcessingScreen(resumeId: 'res_ai_fail'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Extraction Failed'), findsOneWidget);
      expect(
        find.text('Extracted data does not match resume schema.'),
        findsOneWidget,
      );
      expect(find.text('Retry Extraction'), findsOneWidget);
    });

    testWidgets('shows server progress driven by resumes/{id}.progress',
        (tester) async {
      const processingResume = ResumeDoc(
        id: 'res_active',
        uid: 'user_456',
        storagePath: 'resumes/user_456/res_active.pdf',
        status: ResumeDocStatus.processing,
        progress: ResumeProgressStage.skills,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchResumeProvider('res_active').overrideWith(
              (ref) => Stream.value(processingResume),
            ),
          ],
          child: const MaterialApp(
            home: ResumeProcessingScreen(resumeId: 'res_active'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('AI Profile Generation'), findsOneWidget);
      expect(
        find.text('Step 4 of 7: Matching skills to dictionary'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
