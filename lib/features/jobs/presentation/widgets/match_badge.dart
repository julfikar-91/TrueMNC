// lib/features/jobs/presentation/widgets/match_badge.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Accessible Match Badge showing both a textual semantic label and percentage.
/// Does not rely on colour alone for meaning (WCAG AA).
class MatchBadge extends StatelessWidget {
  const MatchBadge({
    super.key,
    required this.score,
    this.label,
    this.compact = false,
  });

  final double score;
  final String? label;
  final bool compact;

  String get _computedLabel {
    if (label != null && label!.isNotEmpty) return label!;
    final s = score.round();
    if (s >= 80) return 'Strong';
    if (s >= 65) return 'Good';
    if (s >= 55) return 'Possible';
    return 'Low';
  }

  Color _badgeColor(ThemeData theme) {
    final s = score.round();
    if (s >= 80) return AppColors.success;
    if (s >= 65) return AppColors.info;
    if (s >= 55) return AppColors.warning;
    return theme.colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _badgeColor(theme);
    final textLabel = _computedLabel;
    final percentStr = '${score.round()}%';

    return Semantics(
      label: 'Match score: $textLabel, $percentStr',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: compact ? 2 : AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color.withOpacity(0.6), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars_rounded,
              size: compact ? 14 : 16,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$textLabel $percentStr',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
