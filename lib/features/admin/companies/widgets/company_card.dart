// lib/features/admin/companies/widgets/company_card.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/company.dart';

/// A card representing a [Company] in an admin list view.
///
/// Tapping the card body calls [onTap]; the trailing edit icon calls [onEdit].
class CompanyCard extends StatelessWidget {
  const CompanyCard({
    super.key,
    required this.company,
    required this.onTap,
    required this.onEdit,
  });

  final Company company;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  // ── helpers ───────────────────────────────────────────────────────────────

  String get _initials {
    final parts = company.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sourceCount = company.sources.length;

    return Semantics(
      label:
          '${company.name}, ${company.isVerified ? "Verified" : "Unverified"}, '
          '$sourceCount ${sourceCount == 1 ? "source" : "sources"}. '
          'Double tap to view details.',
      button: true,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Avatar / Logo ──────────────────────────────────────
                  _CompanyAvatar(
                    logoUrl: company.logoUrl,
                    initials: _initials,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // ── Name / Domain / Chips ──────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          company.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (company.website != null &&
                            company.website!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            company.website!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.secondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _VerificationChip(
                                isVerified: company.isVerified,
                                colorScheme: colorScheme),
                            _SourceCountChip(
                                count: sourceCount,
                                colorScheme: colorScheme,
                                theme: theme),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Edit button ────────────────────────────────────────
                  Semantics(
                    label: 'Edit ${company.name}',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      onPressed: onEdit,
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────

class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({
    required this.logoUrl,
    required this.initials,
    required this.colorScheme,
  });

  final String? logoUrl;
  final String initials;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    const double size = 48;
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(logoUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({
    required this.isVerified,
    required this.colorScheme,
  });

  final bool isVerified;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(isVerified ? 'Verified' : 'Unverified'),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: isVerified ? Colors.green.shade800 : Colors.orange.shade800,
      ),
      backgroundColor:
          isVerified ? Colors.green.shade50 : Colors.orange.shade50,
      side: BorderSide(
        color: isVerified ? Colors.green.shade300 : Colors.orange.shade300,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SourceCountChip extends StatelessWidget {
  const _SourceCountChip({
    required this.count,
    required this.colorScheme,
    required this.theme,
  });

  final int count;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$count ${count == 1 ? "source" : "sources"}'),
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
