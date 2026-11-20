// lib/features/jobs/presentation/widgets/job_match_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../recommendations/providers/recommendation_providers.dart';
import 'match_badge.dart';

/// S22 Job Details Match Card with 5-dimension breakdown, skills, reasons, gaps,
/// experience flag, and disclaimer.
class JobMatchCard extends ConsumerWidget {
  const JobMatchCard({
    super.key,
    required this.jobId,
  });

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    // ── 1. Guest User Prompt ──────────────────────────────────────────────────
    if (user == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Match Analysis',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sign in to see your match',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Log in with your TrueMNC profile to see how your verified skills, experience, and education align with this role.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonal(
                onPressed: () => context.push(AppRoutes.login),
                child: const Text('Sign in to view match'),
              ),
            ],
          ),
        ),
      );
    }

    // ── 2. Authenticated User: Load Match Score ──────────────────────────────
    final matchAsync = ref.watch(jobMatchScoreProvider(jobId));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: matchAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: AppSpacing.sm),
                  Text('Calculating match score...'),
                ],
              ),
            ),
          ),
          error: (err, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match Score',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Could not load match score: $err',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => ref.invalidate(jobMatchScoreProvider(jobId)),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (data) {
            if (data == null) {
              return const Text('Match score unavailable.');
            }

            final score = (data['score'] as num?)?.toDouble() ?? 0.0;
            final label = data['label'] as String? ?? 'Match';
            final breakdown = (data['breakdown'] as Map<String, dynamic>?) ?? {};
            final matchedSkills = List<String>.from(data['matchedSkills'] ?? []);
            final missingSkills = List<String>.from(data['missingSkills'] ?? []);
            final niceToHave = List<String>.from(data['niceToHave'] ?? []);
            final reasons = List<String>.from(data['reasons'] ?? []);
            final gaps = List<String>.from(data['gaps'] ?? []);
            final flags = List<String>.from(data['flags'] ?? []);

            final hasExpFlag = flags.any((f) => f.contains('Add experience for better accuracy'));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Score & Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Candidate Match',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${score.round()}% Overall Alignment',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    MatchBadge(score: score, label: label),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 5 Sub-Score Progress Bars with Text Values
                _SubScoreRow(
                  label: 'Skills',
                  value: (breakdown['skills'] as num?)?.toDouble() ?? 0.0,
                  weight: '40%',
                ),
                _SubScoreRow(
                  label: 'Education',
                  value: (breakdown['education'] as num?)?.toDouble() ?? 0.0,
                  weight: '15%',
                ),
                _SubScoreRow(
                  label: 'Experience',
                  value: (breakdown['experience'] as num?)?.toDouble() ?? 0.0,
                  weight: '15%',
                ),
                _SubScoreRow(
                  label: 'Location',
                  value: (breakdown['location'] as num?)?.toDouble() ?? 0.0,
                  weight: '10%',
                ),
                _SubScoreRow(
                  label: 'Preference',
                  value: (breakdown['preference'] as num?)?.toDouble() ?? 0.0,
                  weight: '20%',
                ),
                const SizedBox(height: AppSpacing.md),

                // Experience Unknown Flag Banner (Linking to S12 profile edit)
                if (hasExpFlag) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.warning.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add experience for better accuracy',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                              Text(
                                'Experience is currently unknown and defaulted to 50.',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.profileManual),
                          child: const Text('Add (S12)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Matched Skills Chips
                if (matchedSkills.isNotEmpty) ...[
                  Text(
                    'Matched Skills',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: matchedSkills.map((s) => _SkillChip(label: s, isMatch: true)).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Missing Skills Chips
                if (missingSkills.isNotEmpty) ...[
                  Text(
                    'Missing Required Skills',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: missingSkills.map((s) => _SkillChip(label: s, isMatch: false)).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Nice to have
                if (niceToHave.isNotEmpty) ...[
                  Text(
                    'Nice to Have Matched',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: niceToHave.map((s) => _SkillChip(label: s, isMatch: true)).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Why it matches
                if (reasons.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'Why it matches:',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  ...reasons.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check, size: 14, color: AppColors.success),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(r, style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Gaps
                if (gaps.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Gaps:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...gaps.map(
                    (g) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.close, size: 14, color: theme.colorScheme.error),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(g, style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Disclaimer
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'Relevance score, not hiring probability. Calculated deterministically from confirmed profile data.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubScoreRow extends StatelessWidget {
  const _SubScoreRow({
    required this.label,
    required this.value,
    required this.weight,
  });

  final String label;
  final double value;
  final String weight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = (value / 100.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label ($weight)',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: clamped,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(
                  value >= 80
                      ? AppColors.success
                      : value >= 60
                          ? AppColors.info
                          : AppColors.warning,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 40,
            child: Text(
              '${value.round()}%',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.label,
    required this.isMatch,
  });

  final String label;
  final bool isMatch;

  @override
  Widget build(BuildContext context) {
    final color = isMatch ? AppColors.success : Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
