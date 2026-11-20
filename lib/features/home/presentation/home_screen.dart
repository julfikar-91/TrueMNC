// lib/features/home/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/demo/demo_nav_sheet.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/offline_chip.dart';
import '../../../core/widgets/skeleton_list.dart';
import '../../../data/models/company.dart';
import '../../../data/models/job.dart';
import '../../../data/models/recommendation.dart';
import '../../../data/repositories/recommendation_repository.dart';
import '../../jobs/presentation/widgets/job_card.dart';
import '../../jobs/presentation/widgets/section_header.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      final msg = await ref.read(recommendationRepositoryProvider).refreshRecommendations();
      if (!mounted) return;

      if (msg != null) {
        // Show rate-limit or error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ref.invalidate(homeRecommendedJobsProvider);
        ref.invalidate(homeSkillMatchesProvider);
        ref.invalidate(homeEducationJobsProvider);
        ref.invalidate(homeRecentlyAddedJobsProvider);
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
    final greeting = ref.watch(greetingProvider);
    final isConfirmed = ref.watch(isProfileConfirmedProvider);
    final isFresher = ref.watch(isFresherCandidateProvider);
    final preferredCity = ref.watch(preferredCityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TrueMNC',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
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
          IconButton(
            icon: const Icon(Icons.bolt, color: Colors.amber),
            tooltip: 'Demo Screen Explorer',
            onPressed: () => showDemoNavSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            // ── Greeting & Offline Chip ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      greeting,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const OfflineChip(label: 'Offline mode'),
                ],
              ),
            ),

            // ── Search Bar Stub ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: InkWell(
                onTap: () => context.push(AppRoutes.search),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Search jobs, skills, or companies...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Guest & Unconfirmed Candidate Banner ────────────────────────
            if (!isConfirmed)
              Padding(
                key: const Key('complete_profile_banner'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.12),
                        theme.colorScheme.secondary.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete your profile for personalised jobs',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Upload your resume or add skills to get accurate match percentages.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.tonal(
                        onPressed: () => context.push(AppRoutes.resumeOnboarding),
                        child: const Text('Complete'),
                      ),
                    ],
                  ),
                ),
              ),

            // ── 1. Recommended For You (Personalised) ────────────────────────
            if (isConfirmed)
              _HomePopulatedRecSection(
                sectionKey: const Key('section_recommended'),
                title: 'Recommended For You',
                subtitle: 'Top match scores calculated for your profile',
                provider: homeRecommendedJobsProvider,
                onSeeAll: () => context.push(AppRoutes.recommendations),
              ),

            // ── 2. Best Skill Matches (Personalised) ─────────────────────────
            if (isConfirmed)
              _HomePopulatedRecSection(
                sectionKey: const Key('section_best_skills'),
                title: 'Best Skill Matches',
                subtitle: 'Positions matching your confirmed skills',
                provider: homeSkillMatchesProvider,
                onSeeAll: () => context.push(AppRoutes.recommendations),
              ),

            // ── 3. Jobs Based on Your Education (Personalised) ───────────────
            if (isConfirmed)
              _HomePopulatedRecSection(
                sectionKey: const Key('section_education'),
                title: 'Jobs Based on Your Education',
                subtitle: 'Aligned with your confirmed degree & field',
                provider: homeEducationJobsProvider,
                onSeeAll: () => context.push(AppRoutes.recommendations),
              ),

            // ── 4. Fresher Opportunities (ONLY if explicitly confirmed) ──────
            if (isFresher)
              _HomeJobsStreamSection(
                sectionKey: const Key('section_fresher'),
                title: 'Fresher Opportunities',
                subtitle: 'Entry-level and 0-year verified openings',
                provider: homeFresherJobsProvider,
              ),

            // ── 5. Near Preferred Locations ──────────────────────────────────
            if (preferredCity != null && preferredCity.isNotEmpty)
              _HomeJobsStreamSection(
                sectionKey: const Key('section_near_location'),
                title: 'Near $preferredCity',
                subtitle: 'Verified openings in or near your preferred city',
                provider: homeNearLocationJobsProvider,
              ),

            // ── 6. Technical Verified Jobs (All Users) ───────────────────────
            _HomeJobsStreamSection(
              sectionKey: const Key('section_technical'),
              title: 'Technical Roles',
              subtitle: 'Engineering, Data, AI/ML, Cloud & Architecture',
              provider: homeTechnicalJobsProvider,
            ),

            // ── 7. Non-Technical Verified Jobs (All Users) ───────────────────
            _HomeJobsStreamSection(
              sectionKey: const Key('section_non_technical'),
              title: 'Non-Technical Roles',
              subtitle: 'HR, Finance, Marketing, Operations & Management',
              provider: homeNonTechnicalJobsProvider,
            ),

            // ── 8. Recently Added (All Users) ────────────────────────────────
            _HomeJobsStreamSection(
              sectionKey: const Key('section_recently_added'),
              title: 'Recently Added',
              subtitle: 'Freshly crawled and verified corporate postings',
              provider: homeRecentlyAddedJobsProvider,
            ),

            // ── 9. Popular Verified Companies ────────────────────────────────
            _HomeCompaniesSection(
              sectionKey: const Key('section_popular_companies'),
              provider: homePopularCompaniesProvider,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Personalised Populated Recommendations Section ────────────────────────────
class _HomePopulatedRecSection extends ConsumerWidget {
  const _HomePopulatedRecSection({
    super.key,
    this.sectionKey,
    required this.title,
    this.subtitle,
    required this.provider,
    this.onSeeAll,
  });

  final Key? sectionKey;
  final String title;
  final String? subtitle;
  final AutoDisposeFutureProvider<List<({Recommendation recommendation, Job job})>> provider;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVal = ref.watch(provider);

    return asyncVal.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SkeletonList(itemCount: 2),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
          child: ListTile(
            title: Text('Error loading $title'),
            subtitle: Text(e.toString()),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(provider),
            ),
          ),
        ),
      ),
      data: (items) {
        // EMPTY RULE: If section is empty, hide it completely on Home!
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          key: sectionKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionHeader(
              title: title,
              subtitle: subtitle,
              onSeeAll: onSeeAll,
            ),
            ...items.take(10).map(
                  (item) => JobCard(
                    job: item.job,
                    recommendation: item.recommendation,
                  ),
                ),
          ],
        );
      },
    );
  }
}

// ── Generic Jobs Stream Section (Non-Personalised or Filtered) ────────────────
class _HomeJobsStreamSection extends ConsumerWidget {
  const _HomeJobsStreamSection({
    super.key,
    this.sectionKey,
    required this.title,
    this.subtitle,
    required this.provider,
    this.onSeeAll,
  });

  final Key? sectionKey;
  final String title;
  final String? subtitle;
  final AutoDisposeStreamProvider<List<Job>> provider;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVal = ref.watch(provider);

    return asyncVal.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SkeletonList(itemCount: 2),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
          child: ListTile(
            title: Text('Error loading $title'),
            subtitle: Text(e.toString()),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(provider),
            ),
          ),
        ),
      ),
      data: (jobs) {
        // EMPTY RULE: If section is empty, hide it completely on Home!
        if (jobs.isEmpty) return const SizedBox.shrink();

        return Column(
          key: sectionKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionHeader(
              title: title,
              subtitle: subtitle,
              onSeeAll: onSeeAll,
            ),
            ...jobs.take(10).map((job) => JobCard(job: job)),
          ],
        );
      },
    );
  }
}

// ── Popular Verified Companies Section ────────────────────────────────────────
class _HomeCompaniesSection extends ConsumerWidget {
  const _HomeCompaniesSection({
    super.key,
    this.sectionKey,
    required this.provider,
  });

  final Key? sectionKey;
  final AutoDisposeStreamProvider<List<Company>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncVal = ref.watch(provider);

    return asyncVal.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (companies) {
        if (companies.isEmpty) return const SizedBox.shrink();

        return Column(
          key: sectionKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeader(
              title: 'Popular Companies',
              subtitle: 'Verified corporate portals with active hiring',
            ),
            SizedBox(
              height: 100,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: companies.take(10).length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final company = companies[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.business_rounded, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            company.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (company.isVerified)
                            const Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
