// lib/features/recommendations/presentation/recommendations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/skeleton_list.dart';
import '../../../data/models/job.dart';
import '../../../data/models/recommendation.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/recommendation_repository.dart';
import '../../home/providers/home_providers.dart';
import '../../jobs/presentation/widgets/job_card.dart';
import '../../jobs/presentation/widgets/section_header.dart';
import '../providers/recommendation_providers.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  bool _isRefreshing = false;
  bool _isDeepMatching = false;

  Future<void> _showDeepMatchConfirmationSheet() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final remaining = await ref
        .read(recommendationRepositoryProvider)
        .getRemainingDeepMatches(user.uid);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'AI Deep Match',
                    style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'AI Deep Match evaluates qualitative alignment between your confirmed profile and top recommended jobs to fine-tune your match ranking.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Privacy Guarantee: Only a compact summary (confirmed skills, education, preferences) is sent. Your resume file is never sent.',
                        style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Expanded(child: Text('Daily Limit: 3 uses per day')),
                  Text(
                    'Remaining today: $remaining/3',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('confirm_deep_match_btn'),
                  onPressed: remaining <= 0
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _executeDeepMatch();
                        },
                  child: Text(remaining <= 0
                      ? 'Daily Limit Reached'
                      : 'Confirm Deep Match'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeDeepMatch() async {
    setState(() => _isDeepMatching = true);
    try {
      final res =
          await ref.read(recommendationRepositoryProvider).triggerDeepMatch();
      if (!mounted) return;

      if (res['fallback'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI service temporarily unavailable; existing match scores preserved.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      } else {
        ref.invalidate(topRecommendationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Deep Match completed! Recommendations updated with AI reasons.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeepMatching = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      final msg = await ref.read(recommendationRepositoryProvider).refreshRecommendations();
      if (!mounted) return;

      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ref.invalidate(topRecommendationsProvider);
        ref.invalidate(skillMatchesProvider);
        ref.invalidate(educationMatchesProvider);
        ref.invalidate(locationMatchesProvider);
        ref.invalidate(recentlyMatchingProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recommendations refreshed!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfirmed = ref.watch(isProfileConfirmedProvider);
    final allRecsAsync = ref.watch(topRecommendationsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final isGuest = user == null || user.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh recommendations',
            onPressed: _isRefreshing ? null : _handleRefresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: allRecsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: SkeletonList(itemCount: 4),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.warning),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Unable to load recommendations',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => ref.invalidate(topRecommendationsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (allRecs) {
            if (!isConfirmed || allRecs.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  EmptyStateWidget(
                    icon: Icons.auto_awesome,
                    title: isConfirmed
                        ? 'No Recommendations Found'
                        : 'Complete Profile For Matches',
                    subtitle: isConfirmed
                        ? 'Broaden your career preferences (locations, roles) to receive new matches.'
                        : 'Upload your resume or confirm your skills and education to unlock tailored recommendations.',
                    actionLabel: isConfirmed ? 'Edit Preferences' : 'Complete Profile',
                    onAction: () {
                      if (isConfirmed) {
                        context.push(AppRoutes.preferences);
                      } else {
                        context.push(AppRoutes.resumeOnboarding);
                      }
                    },
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                // ── Deep Match (AI) ──────────────────────────────────────────
                if (!isGuest && isConfirmed) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: OutlinedButton.icon(
                      key: const Key('deep_match_btn'),
                      icon: _isDeepMatching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.auto_awesome,
                              color: theme.colorScheme.primary,
                              size: 18,
                            ),
                      label: const Text('Deep Match (uses AI, 3 per day)'),
                      onPressed: _isDeepMatching
                          ? null
                          : _showDeepMatchConfirmationSheet,
                    ),
                  ),
                ],

                // ── 1. Best Matches ──────────────────────────────────────────
                _RecSection(
                  title: 'Best Matches',
                  subtitle: 'Highest overall alignment with your qualifications',
                  recProvider: topRecommendationsProvider,
                ),

                // ── 2. Recently Matching ─────────────────────────────────────
                _RecSection(
                  title: 'Recently Matching',
                  subtitle: 'Newly active positions matching your criteria',
                  recProvider: recentlyMatchingProvider,
                ),

                // ── 3. Skill-Based ───────────────────────────────────────────
                _RecSection(
                  title: 'Skill-Based Matches',
                  subtitle: 'Roles heavily matching your confirmed technical skills',
                  recProvider: skillMatchesProvider,
                ),

                // ── 4. Education-Based ───────────────────────────────────────
                _RecSection(
                  title: 'Education-Based Matches',
                  subtitle: 'Positions aligned with your degree and field',
                  recProvider: educationMatchesProvider,
                ),

                // ── 5. Location-Based ────────────────────────────────────────
                _RecSection(
                  title: 'Location-Based Matches',
                  subtitle: 'Matches in or near your preferred locations',
                  recProvider: locationMatchesProvider,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecSection extends ConsumerWidget {
  const _RecSection({
    required this.title,
    this.subtitle,
    required this.recProvider,
  });

  final String title;
  final String? subtitle;
  final AutoDisposeStreamProvider<List<Recommendation>> recProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(recProvider);

    return recsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SkeletonList(itemCount: 2),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (recs) {
        if (recs.isEmpty) return const SizedBox.shrink();

        final populatedAsync = ref.watch(populatedRecommendationsProvider(recs));
        return populatedAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: SkeletonList(itemCount: 2),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SectionHeader(
                  title: title,
                  subtitle: subtitle,
                ),
                ...items.map(
                  (item) => JobCard(
                    job: item.job,
                    recommendation: item.recommendation,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
