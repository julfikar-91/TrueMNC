// lib/features/jobs/presentation/widgets/status_chip.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/enums.dart';

/// Status chip for job lifecycle state.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
  });

  final JobStatus status;

  String get _label => switch (status) {
        JobStatus.active => 'Active',
        JobStatus.closingSoon => 'Closing Soon',
        JobStatus.closed => 'Closed',
        JobStatus.expired => 'Expired',
        JobStatus.rejected => 'Rejected',
        JobStatus.duplicate => 'Duplicate',
        JobStatus.pendingReview => 'In Review',
        JobStatus.draftRaw => 'Draft',
      };

  Color _chipColor(ThemeData theme) => switch (status) {
        JobStatus.active => AppColors.success,
        JobStatus.closingSoon => AppColors.warning,
        JobStatus.closed || JobStatus.expired => theme.colorScheme.error,
        JobStatus.pendingReview => AppColors.warning,
        _ => theme.colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _chipColor(theme);

    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
