// lib/features/resume/presentation/resume_onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/auth_repository.dart';

class ResumeOnboardingScreen extends ConsumerWidget {
  const ResumeOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Future<void> handleSkip() async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid != null) {
        try {
          await ref.read(profileRepositoryProvider).updateUser(uid, {
            'resume_onboarding_done': true,
          });
        } catch (_) {
          // If network is offline, continue navigation to home
        }
      }
      if (context.mounted) {
        context.go(AppRoutes.home);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Setup'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: handleSkip,
            child: const Text('Skip for Now'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 52,
                    color: colorScheme.primary,
                    semanticLabel: 'AI Resume Analyzer',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Build Your Professional Profile with AI',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Upload your PDF or DOCX resume to have your technical skills, work history, and education automatically structured with privacy-first AI extraction.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),

              // Button 1: Upload Resume
              AppButton(
                label: 'Upload Resume',
                icon: const Icon(Icons.upload_file_rounded),
                onPressed: () => context.push(AppRoutes.resumeUpload),
              ),
              const SizedBox(height: AppSpacing.md),

              // Button 2: Create Profile Manually
              AppButton.secondary(
                label: 'Create Profile Manually',
                icon: const Icon(Icons.edit_note_rounded),
                onPressed: () => context.push(AppRoutes.profileManual),
              ),
              const SizedBox(height: AppSpacing.md),

              // Button 3: Skip for Now
              AppButton.text(
                label: 'Skip for Now',
                onPressed: handleSkip,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Privacy Note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Privacy note: Your resume is processed securely. We never share your personal data with third parties or public AI training sets.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
