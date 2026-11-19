// lib/features/admin/collection/presentation/collection_monitor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/collection_run_model.dart';
import '../../../../data/repositories/admin_repository.dart';

/// Provider for collection runs telemetry across all sources.
final allCollectionRunsProvider =
    StreamProvider.autoDispose<List<CollectionRunModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchCollectionRuns(limit: 50);
});

class CollectionMonitorScreen extends ConsumerWidget {
  const CollectionMonitorScreen({super.key});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '—';
    final seconds = d.inSeconds;
    if (seconds < 60) return '${seconds}s';
    return '${d.inMinutes}m ${seconds % 60}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final runsAsync = ref.watch(allCollectionRunsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(allCollectionRunsProvider),
          ),
        ],
      ),
      body: runsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text('Error loading collection monitor: $err'),
          ),
        ),
        data: (runs) {
          if (runs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_outlined,
                        size: 64, color: theme.colorScheme.outline),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Collection Runs Yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Automated runs scheduled every 15 minutes will appear here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: runs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final run = runs[index];
              final isSuccess = run.isSuccess;
              final isFailed = run.isFailed;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(
                    color: isFailed
                        ? Colors.red.withOpacity(0.5)
                        : theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Status badge & timestamp
                      Row(
                        children: [
                          Icon(
                            isSuccess
                                ? Icons.check_circle_outline
                                : isFailed
                                    ? Icons.error_outline
                                    : Icons.sync,
                            color: isSuccess
                                ? Colors.green
                                : isFailed
                                    ? Colors.red
                                    : Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            run.status,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSuccess
                                  ? Colors.green
                                  : isFailed
                                      ? Colors.red
                                      : Colors.blue,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(run.startedAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Text(
                        'Company: ${run.companyId} • Source: ${run.sourceId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Metrics chips: duration, fetched, new, changed, closed
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _MetricChip(
                            label: 'Duration',
                            value: _formatDuration(run.duration),
                            icon: Icons.timer_outlined,
                          ),
                          _MetricChip(
                            label: 'Fetched',
                            value: '${run.jobsFound}',
                            icon: Icons.cloud_download_outlined,
                          ),
                          _MetricChip(
                            label: 'New',
                            value: '${run.jobsCreated}',
                            icon: Icons.add_circle_outline,
                            color: Colors.green,
                          ),
                          _MetricChip(
                            label: 'Changed',
                            value: '${run.jobsUpdated}',
                            icon: Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          _MetricChip(
                            label: 'Closed',
                            value: '${run.jobsClosed}',
                            icon: Icons.archive_outlined,
                            color: Colors.grey,
                          ),
                        ],
                      ),

                      if (run.errors.isNotEmpty || run.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            run.errorMessage ?? run.errors.join('\n'),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
