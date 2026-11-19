// lib/features/resume/presentation/resume_processing_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/resume_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/resume_repository.dart';

class ResumeProcessingScreen extends ConsumerStatefulWidget {
  const ResumeProcessingScreen({super.key, this.resumeId});

  final String? resumeId;

  @override
  ConsumerState<ResumeProcessingScreen> createState() =>
      _ResumeProcessingScreenState();
}

class _ResumeProcessingScreenState
    extends ConsumerState<ResumeProcessingScreen> {
  Timer? _timeoutTimer;
  bool _isTimedOut = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // 90 seconds timeout tracker
    _timeoutTimer = Timer(const Duration(seconds: 90), () {
      if (mounted) {
        setState(() {
          _isTimedOut = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _onSuccess(String id) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _timeoutTimer?.cancel();
    // Navigate to Profile Preview
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('${AppRoutes.profilePreview}?id=$id');
      }
    });
  }

  Future<void> _handleCancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Parsing?'),
        content: const Text(
          'Are you sure you want to cancel resume processing? You can try again or set up your profile manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Waiting'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.go(AppRoutes.resumeUpload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Resolve resume ID
    final effectiveResumeId = widget.resumeId ??
        ref.watch(userDocProvider).valueOrNull?.toMap()['current_resume_id'] as String? ??
        '';

    if (effectiveResumeId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Processing Resume')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, size: 48),
              const SizedBox(height: AppSpacing.md),
              const Text('No active resume parsing in progress.'),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Upload Resume',
                onPressed: () => context.go(AppRoutes.resumeUpload),
              ),
            ],
          ),
        ),
      );
    }

    final resumeAsync = ref.watch(watchResumeProvider(effectiveResumeId));

    return resumeAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Processing Resume')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Processing Resume')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 54, color: colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text('Connection Error', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(watchResumeProvider(effectiveResumeId)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (resumeDoc) {
        if (resumeDoc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Processing Resume')),
            body: const Center(child: Text('Resume document not found.')),
          );
        }

        // Trigger navigation ONLY on PARSED or PARTIAL
        if (resumeDoc.isSuccess) {
          _onSuccess(effectiveResumeId);
        }

        final currentStage = resumeDoc.progress;
        final currentStep = currentStage.stepNumber;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Processing Resume'),
            automaticallyImplyLeading: false,
            actions: [
              TextButton(
                onPressed: () => _handleCancel(effectiveResumeId),
                child: const Text('Cancel'),
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
                  // Header
                  if (!resumeDoc.isFailed) ...[
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology_rounded,
                          size: 40,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'AI Profile Generation',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Step $currentStep of 7: ${currentStage.displayName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // 90s Background Timeout Banner
                  if (_isTimedOut && !resumeDoc.isFailed) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.tertiary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, color: colorScheme.onTertiaryContainer),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Processing in background, we will notify you.',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Resume parsing is taking longer than usual. You can safely return to Home while our background engine finishes.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: () => context.go(AppRoutes.home),
                              child: const Text('Go to Home'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // FAILED STATE VIEW
                  if (resumeDoc.isFailed) ...[
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Extraction Failed',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      resumeDoc.errorMessage ??
                          (resumeDoc.status == ResumeDocStatus.failedUnreadable
                              ? 'Your document could not be read. Please ensure it contains selectable text, is not password protected, and is under 10 pages.'
                              : 'AI parsing failed. Our extraction model could not format your resume.'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 2),

                    // Option 1: Retry
                    AppButton(
                      label: 'Retry Extraction',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () async {
                        try {
                          await ref
                              .read(resumeRepositoryProvider)
                              .parseResume(resumeId: effectiveResumeId);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Retry failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Option 2: Replace File
                    AppButton.secondary(
                      label: 'Replace Resume File',
                      icon: const Icon(Icons.upload_file_rounded),
                      onPressed: () => context.go(AppRoutes.resumeUpload),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Option 3: Manual Profile
                    AppButton.text(
                      label: 'Create Profile Manually',
                      onPressed: () => context.go(AppRoutes.profileManual),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ] else ...[
                    // ACTIVE 7-STAGE PROGRESS LIST (Driven ONLY by server progress)
                    Expanded(
                      child: ListView.separated(
                        itemCount: ResumeProgressStage.values.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final stage = ResumeProgressStage.values[index];
                          final isCompleted = currentStep > stage.stepNumber;
                          final isCurrent = currentStep == stage.stepNumber;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm + 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? colorScheme.primaryContainer.withOpacity(0.3)
                                  : isCompleted
                                      ? colorScheme.surfaceContainerHighest.withOpacity(0.4)
                                      : colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (isCompleted)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: colorScheme.primary,
                                    size: 24,
                                  )
                                else if (isCurrent)
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: colorScheme.outline,
                                    size: 22,
                                  ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    stage.displayName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isCurrent
                                          ? colorScheme.primary
                                          : isCompleted
                                              ? colorScheme.onSurface
                                              : colorScheme.outline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
