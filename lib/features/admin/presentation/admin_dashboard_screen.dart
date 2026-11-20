// lib/features/admin/presentation/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/demo/demo_nav_sheet.dart';
import '../../../core/demo/demo_provider.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/auth_repository.dart';

import '../../../data/repositories/admin_repository.dart';

final adminStatsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).watchStats();
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userRole = ref.watch(claimsProvider).valueOrNull ?? UserRole.user;
    final isSuperAdmin = userRole == UserRole.superAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: Colors.amber),
            tooltip: 'Demo Screen Explorer',
            onPressed: () => showDemoNavSheet(context),
          ),
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSuperAdmin
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              isSuperAdmin ? 'SUPER_ADMIN' : 'ADMIN',
              style: TextStyle(
                color: isSuperAdmin
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSecondaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Welcome Card
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSuperAdmin
                              ? 'Super Administrator Console'
                              : 'Administrator Console',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSuperAdmin
                              ? 'Full system privileges: configuration, roles, audits & companies.'
                              : 'Standard privileges: manage company directory & view audit logs.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── KPI Telemetry Row ───────────────────────────────────────────────
          Consumer(
            builder: (context, ref, _) {
              final statsAsync = ref.watch(adminStatsProvider);
              final stats = statsAsync.valueOrNull ?? {};
              final activeJobs = stats['jobs_ACTIVE'] ?? 0;
              final pendingReview = stats['jobs_PENDING_REVIEW'] ?? 0;

              return Row(
                children: [
                  // KPI 1: Active Jobs -> opens A07 filtered to ACTIVE
                  Expanded(
                    child: _KpiCard(
                      key: const Key('kpi_active_jobs'),
                      label: 'Active Jobs',
                      count: '$activeJobs',
                      icon: Icons.work,
                      color: Colors.green,
                      onTap: () => context.push('/admin/jobs?status=ACTIVE'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // KPI 2: Review Queue -> opens A09
                  Expanded(
                    child: _KpiCard(
                      key: const Key('kpi_review_queue'),
                      label: 'Review Queue',
                      count: '$pendingReview',
                      icon: Icons.rate_review,
                      color: Colors.orange,
                      onTap: () => context.push('/admin/review-queue'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // KPI 3: Collection Monitor -> opens A10
                  Expanded(
                    child: _KpiCard(
                      key: const Key('kpi_collection_monitor'),
                      label: 'Monitor',
                      count: 'Live',
                      icon: Icons.monitor_heart,
                      color: Colors.blue,
                      onTap: () => context.push('/admin/collection-monitor'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Operations',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 1. Company Management (All Admins)
          _AdminNavigationCard(
            key: const Key('admin_companies_tile'),
            title: 'Company Directory',
            subtitle:
                'Add, verify, and manage corporate profiles and career sources.',
            icon: Icons.business,
            iconColor: Colors.teal,
            onTap: () => context.push('/admin/companies'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 2. Audit Logs (All Admins)
          _AdminNavigationCard(
            key: const Key('admin_audit_logs_tile'),
            title: 'Audit Logs',
            subtitle:
                'Inspect immutable records of administrative actions & changes.',
            icon: Icons.history,
            iconColor: Colors.purple,
            onTap: () => context.push('/admin/audit-logs'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 3. All Corporate Jobs (A07)
          _AdminNavigationCard(
            key: const Key('admin_all_jobs_tile'),
            title: 'All Corporate Jobs',
            subtitle:
                'Explore, filter, inspect and perform bulk actions on company job posts.',
            icon: Icons.work_outline,
            iconColor: Colors.indigo,
            onTap: () => context.push('/admin/jobs'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 4. Review Queue (A09)
          _AdminNavigationCard(
            key: const Key('admin_review_queue_tile'),
            title: 'Review Queue',
            subtitle:
                'Review flagged postings, resolve rule violations and approve jobs.',
            icon: Icons.rate_review_outlined,
            iconColor: Colors.orange.shade700,
            onTap: () => context.push('/admin/review-queue'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 5. Collection Monitor (A10)
          _AdminNavigationCard(
            key: const Key('admin_collection_monitor_tile'),
            title: 'Collection Monitor',
            subtitle:
                'Live pipeline telemetry: automated adapter runs, new jobs, errors.',
            icon: Icons.monitor_heart_outlined,
            iconColor: Colors.blue,
            onTap: () => context.push('/admin/collection-monitor'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 6. User Reports (A12)
          _AdminNavigationCard(
            key: const Key('admin_user_reports_tile'),
            title: 'User Reports',
            subtitle:
                'Review community-submitted reports on jobs and application issues.',
            icon: Icons.report_problem_outlined,
            iconColor: Colors.red.shade700,
            onTap: () => context.push('/admin/reports'),
          ),

          // ── SUPER_ADMIN ONLY SECTION ────────────────────────────────────────
          if (isSuperAdmin) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Super Admin Controls',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // A15. Administrator Management (SUPER_ADMIN only)
            _AdminNavigationCard(
              key: const Key('admin_administrators_tile'),
              title: 'Administrator Management',
              subtitle:
                  'Manage administrative roles, add admins by email, revoke access.',
              icon: Icons.manage_accounts,
              iconColor: Colors.purple,
              badgeText: 'SUPER_ADMIN',
              onTap: () => context.push('/admin/administrators'),
            ),
            const SizedBox(height: AppSpacing.sm),

            // A17. System Configuration (SUPER_ADMIN only)
            _AdminNavigationCard(
              key: const Key('admin_system_config_tile'),
              title: 'System Configuration',
              subtitle:
                  'Tune scoring weights (must sum to 100), thresholds, AI models, flags.',
              icon: Icons.settings_suggest,
              iconColor: Colors.orange.shade800,
              badgeText: 'SUPER_ADMIN',
              onTap: () => context.push('/admin/config'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminNavigationCard extends StatelessWidget {
  const _AdminNavigationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badgeText,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                count,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
