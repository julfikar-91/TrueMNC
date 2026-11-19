// lib/features/admin/companies/widgets/company_domain_warning_banner.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// A warning banner used to surface domain-related issues such as
/// `DUPLICATE_DOMAIN` conflicts or pending domain-change confirmations.
///
/// Background: [ColorScheme.errorContainer]
/// Text / icon: [ColorScheme.onErrorContainer]
class CompanyDomainWarningBanner extends StatelessWidget {
  const CompanyDomainWarningBanner({
    super.key,
    required this.message,
  });

  /// The human-readable warning text to display.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fgColor = colorScheme.onErrorContainer;

    return Semantics(
      label: 'Warning: $message',
      liveRegion: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: fgColor,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodySmall?.copyWith(color: fgColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
