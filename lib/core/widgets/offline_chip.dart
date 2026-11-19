// lib/core/widgets/offline_chip.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Offline status indicator chip that informs the user about lack of connection.
/// Designed with WCAG AA contrast and minimum 48dp touch target if tapped.
class OfflineChip extends StatelessWidget {
  const OfflineChip({
    super.key,
    this.label = 'Offline Mode',
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chipContent = Container(
      constraints: const BoxConstraints(
        minHeight: AppSpacing.minTouchTarget,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.warning,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Network status: $label',
      button: onTap != null,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: chipContent,
            )
          : chipContent,
    );
  }
}
