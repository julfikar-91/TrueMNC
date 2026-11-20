// lib/features/jobs/presentation/widgets/job_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/job.dart';
import '../../../../data/models/recommendation.dart';
import 'match_badge.dart';
import 'status_chip.dart';
import 'verification_badge.dart';

/// Reusable job card for discovery sections and search results.
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    this.recommendation,
    this.onTap,
  });

  final Job job;
  final Recommendation? recommendation;
  final VoidCallback? onTap;

  String _formatLocation(Job j) {
    if (j.city != null && j.city!.isNotEmpty) {
      if (j.state != null && j.state!.isNotEmpty) {
        return '${j.city}, ${j.state}';
      }
      return j.city!;
    }
    if (j.locations.isNotEmpty) {
      return j.locations.first;
    }
    return 'India';
  }

  String _workModeLabel(Job j) {
    final mode = j.workMode.name.toUpperCase();
    return mode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topReason = recommendation?.reasons.isNotEmpty == true
        ? recommendation!.reasons.first
        : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap ??
            () {
              if (job.id != null) {
                context.push('/job/${job.id}');
              }
            },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Badges & Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (recommendation != null)
                          MatchBadge(
                            score: recommendation!.score,
                            compact: true,
                          ),
                        VerificationBadge(
                          sourcePlatform: 'Official',
                          lastVerifiedAt: job.verification.checkedAt,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: job.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Row 2: Title
              Text(
                job.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Row 3: Company Name
              Text(
                job.companyName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Row 4: Meta chips (location, work mode, exp)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatLocation(job),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_center_outlined,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _workModeLabel(job),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (job.expMin != null || job.expMax != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timeline_rounded,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${job.expMin ?? 0}${job.expMax != null ? '-${job.expMax}' : '+'} yrs',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Top Match Reason if present
              if (topReason != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      if (topReason.startsWith('[AI]') ||
                          topReason.contains('AI:')) ...[
                        Container(
                          key: const Key('ai_reason_badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          topReason.replaceFirst('[AI]', '').trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
