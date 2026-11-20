// lib/features/jobs/presentation/widgets/verification_badge.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Verification badge indicating official source ATS/portal and recency.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    super.key,
    this.sourcePlatform,
    this.lastVerifiedAt,
    this.compact = false,
  });

  final String? sourcePlatform;
  final DateTime? lastVerifiedAt;
  final bool compact;

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 59)}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = (sourcePlatform != null && sourcePlatform!.isNotEmpty)
        ? sourcePlatform!
        : 'Official Portal';
    final timeStr = lastVerifiedAt != null ? _formatRelativeTime(lastVerifiedAt!) : 'Verified';
    final displayText = compact ? platform : '$platform • $timeStr';

    return Semantics(
      label: 'Verified job from $platform, $timeStr',
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.sm + 2,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.success.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              displayText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
