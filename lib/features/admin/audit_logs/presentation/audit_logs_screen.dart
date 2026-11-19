// lib/features/admin/audit_logs/presentation/audit_logs_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../data/models/audit_log.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/paged_controller.dart';
import '../providers/audit_logs_providers.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final _scrollController = ScrollController();
  final _actorController = TextEditingController();
  final _targetController = TextEditingController();
  bool _filtersExpanded = false;

  static const _availableActions = [
    'ALL',
    'SET_USER_ROLE',
    'UPDATE_SCORING_CONFIG',
    'UPDATE_APP_CONFIG',
    'UPSERT_COMPANY',
    'VERIFY_JOB',
    'SYSTEM_EVENT',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _actorController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(auditLogsPagedProvider.notifier).loadMore();
    }
  }

  Future<void> _pickDateRange() async {
    final current = ref.read(auditDateRangeFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: current,
    );

    if (picked != null) {
      ref.read(auditDateRangeFilterProvider.notifier).state = picked;
    }
  }

  void _clearFilters() {
    _actorController.clear();
    _targetController.clear();
    ref.read(auditActionFilterProvider.notifier).state = 'ALL';
    ref.read(auditActorFilterProvider.notifier).state = '';
    ref.read(auditTargetFilterProvider.notifier).state = '';
    ref.read(auditDateRangeFilterProvider.notifier).state = null;
  }

  void _exportCsv(List<AuditLog> logs) {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audit logs loaded to export.')),
      );
      return;
    }

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln(
        'ID,Timestamp,Action,PerformedBy,TargetType,TargetId,IPAddress,Details');

    for (final log in logs) {
      final id = _escapeCsv(log.id ?? '');
      final time = _escapeCsv(log.timestamp?.toIso8601String() ?? '');
      final action = _escapeCsv(log.action);
      final actor = _escapeCsv(log.performedBy);
      final targetType = _escapeCsv(log.targetType);
      final targetId = _escapeCsv(log.targetId);
      final ip = _escapeCsv(log.ipAddress ?? '');
      final details = _escapeCsv(jsonEncode(log.details ?? {}));

      buffer.writeln(
          '$id,$time,$action,$actor,$targetType,$targetId,$ip,$details');
    }

    final csvText = buffer.toString();
    Clipboard.setData(ClipboardData(text: csvText));

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download_done, color: AppColors.success),
            SizedBox(width: AppSpacing.sm),
            Text('CSV Export Generated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully generated CSV for ${logs.length} loaded records and copied to clipboard.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 120,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: SingleChildScrollView(
                child: Text(
                  csvText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _showDetailBottomSheet(BuildContext context, AuditLog log) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _AuditDetailBottomSheet(log: log),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userRole = ref.watch(claimsProvider).valueOrNull ?? UserRole.user;
    final isSuperAdmin = userRole == UserRole.superAdmin;

    final pagedState = ref.watch(auditLogsPagedProvider);
    final currentAction = ref.watch(auditActionFilterProvider);
    final currentDateRange = ref.watch(auditDateRangeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: Icon(
              _filtersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            tooltip: 'Toggle Filters',
            onPressed: () {
              setState(() {
                _filtersExpanded = !_filtersExpanded;
              });
            },
          ),
          // Export CSV visible ONLY for SUPER_ADMIN
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export CSV (SUPER_ADMIN)',
              onPressed: () => _exportCsv(pagedState.items),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Panel
          if (_filtersExpanded)
            Card(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Filters',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Action dropdown
                    DropdownButtonFormField<String>(
                      initialValue: currentAction,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        isDense: true,
                      ),
                      items: _availableActions
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(auditActionFilterProvider.notifier).state =
                              val;
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Actor input
                    TextField(
                      controller: _actorController,
                      decoration: InputDecoration(
                        labelText: 'Filter by Actor (UID or Email)',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, size: 20),
                          onPressed: () {
                            ref.read(auditActorFilterProvider.notifier).state =
                                _actorController.text.trim();
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                        ref.read(auditActorFilterProvider.notifier).state =
                            val.trim();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Target input
                    TextField(
                      controller: _targetController,
                      decoration: InputDecoration(
                        labelText: 'Filter by Target (Path or ID)',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, size: 20),
                          onPressed: () {
                            ref.read(auditTargetFilterProvider.notifier).state =
                                _targetController.text.trim();
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                        ref.read(auditTargetFilterProvider.notifier).state =
                            val.trim();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Date range picker button
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        currentDateRange == null
                            ? 'Select Date Range'
                            : '${_formatShortDate(currentDateRange.start)} - ${_formatShortDate(currentDateRange.end)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main List
          Expanded(
            child: _buildListContent(pagedState),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(PagedState<AuditLog> pagedState) {
    if (pagedState.isLoading && pagedState.items.isEmpty) {
      return const SkeletonList(itemCount: 6);
    }

    if (pagedState.error != null && pagedState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load audit logs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                pagedState.error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () =>
                    ref.read(auditLogsPagedProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (pagedState.items.isEmpty) {
      return EmptyStateWidget(
        title: 'No Audit Logs Found',
        subtitle: 'Try adjusting your filters or date range.',
        icon: Icons.history_outlined,
        actionLabel: 'Reset Filters',
        onAction: _clearFilters,
      );
    }

    final items = pagedState.items;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(auditLogsPagedProvider.notifier).refresh();
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length + (pagedState.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final log = items[index];
          return _AuditLogCard(
            log: log,
            onTap: () => _showDetailBottomSheet(context, log),
          );
        },
      ),
    );
  }

  String _formatShortDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({
    required this.log,
    required this.onTap,
  });

  final AuditLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = log.timestamp != null
        ? '${_pad(log.timestamp!.day)}/${_pad(log.timestamp!.month)}/${log.timestamp!.year} ${_pad(log.timestamp!.hour)}:${_pad(log.timestamp!.minute)}'
        : 'Unknown time';

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ActionChip(action: log.action),
                  const Spacer(),
                  Text(
                    timestamp,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Actor: ${log.performedBy}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.track_changes_outlined, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Target: ${log.targetType} / ${log.targetId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;

    if (action.contains('ROLE')) {
      color = Colors.purple;
    } else if (action.contains('CONFIG')) {
      color = Colors.blue;
    } else if (action.contains('COMPANY')) {
      color = Colors.teal;
    } else if (action.contains('VERIFY')) {
      color = Colors.green;
    } else {
      color = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        action,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AuditDetailBottomSheet extends StatelessWidget {
  const _AuditDetailBottomSheet({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const jsonEncoder = JsonEncoder.withIndent('  ');

    final beforeJson =
        log.before != null ? jsonEncoder.convert(log.before) : null;
    final afterJson = log.after != null ? jsonEncoder.convert(log.after) : null;
    final detailsJson =
        (beforeJson == null && afterJson == null && log.details != null)
            ? jsonEncoder.convert(log.details)
            : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                _ActionChip(action: log.action),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _infoRow('Log ID', log.id ?? '—'),
            _infoRow('Timestamp', log.timestamp?.toIso8601String() ?? '—'),
            _infoRow('Actor UID', log.performedBy),
            _infoRow('Target', '${log.targetType} / ${log.targetId}'),
            if (log.ipAddress != null)
              _infoRow('IP Hash / Address', log.ipAddress!),
            if (log.userAgent != null) _infoRow('User Agent', log.userAgent!),
            const Divider(height: AppSpacing.xl),

            // Diff Section: Before / After
            if (beforeJson != null || afterJson != null) ...[
              Text(
                'State Transition (Before / After)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (beforeJson != null) ...[
                _codeBox(
                  context,
                  title: 'BEFORE',
                  json: beforeJson,
                  color: Colors.red.shade700,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (afterJson != null) ...[
                _codeBox(
                  context,
                  title: 'AFTER',
                  json: afterJson,
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ] else if (detailsJson != null) ...[
              Text(
                'Details / Metadata',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _codeBox(
                context,
                title: 'DETAILS',
                json: detailsJson,
                color: theme.colorScheme.primary,
              ),
            ] else ...[
              Text(
                'No additional before/after state recorded for this entry.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBox(
    BuildContext context, {
    required String title,
    required String json,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: SelectableText(
            json,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
