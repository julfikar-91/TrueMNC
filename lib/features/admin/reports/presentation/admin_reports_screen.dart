// lib/features/admin/reports/presentation/admin_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../data/models/user_report.dart';
import '../../../../data/repositories/admin_report_repository.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  UserReportStatus? _filterStatus;
  bool _isLoading = false;
  List<UserReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(adminReportRepositoryProvider).getPagedReports(
            status: _filterStatus,
            pageSize: 30,
          );
      if (mounted) {
        setState(() {
          _reports = res.items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reports = [];
          _isLoading = false;
        });
      }
    }
  }

  void _openUpdateDialog(UserReport report) {
    var selectedStatus = report.status;
    final noteController = TextEditingController(text: report.adminNote ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Report & Reply'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report ID: ${report.id}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: AppSpacing.sm),
                const Text('New Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<UserReportStatus>(
                  key: const Key('admin_status_dropdown'),
                  value: selectedStatus,
                  items: UserReportStatus.values.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s.label));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Admin Reply / Note (In-app notification to reporter):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  key: const Key('admin_reply_input'),
                  controller: noteController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    hintText: 'Enter response to notify the user...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('admin_save_report_btn'),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await ref
                            .read(adminReportRepositoryProvider)
                            .updateReportStatus(
                              reportId: report.id,
                              status: selectedStatus,
                              adminNote: noteController.text.trim(),
                            );
                        if (mounted) {
                          Navigator.of(ctx).pop();
                          _fetchReports();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report updated and notification queued.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update & Notify'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(UserReportStatus status) {
    Color color;
    switch (status) {
      case UserReportStatus.open:
        color = Colors.blue;
        break;
      case UserReportStatus.inReview:
        color = Colors.orange;
        break;
      case UserReportStatus.resolved:
        color = Colors.green;
        break;
      case UserReportStatus.rejected:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Reports (A12)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh reports',
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            color: theme.colorScheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    key: const Key('filter_status_all'),
                    label: const Text('All'),
                    selected: _filterStatus == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filterStatus = null);
                        _fetchReports();
                      }
                    },
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ...UserReportStatus.values.map((status) {
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        key: Key('filter_status_${status.name}'),
                        label: Text(status.label),
                        selected: _filterStatus == status,
                        onSelected: (selected) {
                          setState(() => _filterStatus = selected ? status : null);
                          _fetchReports();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Reports List
          Expanded(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SkeletonList(itemCount: 4),
                  )
                : _reports.isEmpty
                    ? const Center(
                        child: EmptyStateWidget(
                          icon: Icons.check_circle_outline,
                          title: 'No Reports Found',
                          subtitle: 'There are no active user reports under this status filter.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _reports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          final isAutoFlagged = (report.jobReportCount ?? 0) >= 3;

                          return Card(
                            key: Key('admin_report_card_${report.id}'),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              side: BorderSide(
                                color: isAutoFlagged
                                    ? Colors.red.shade300
                                    : theme.colorScheme.outlineVariant.withOpacity(0.5),
                                width: isAutoFlagged ? 1.5 : 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Auto-flag Badge
                                  if (isAutoFlagged) ...[
                                    Container(
                                      key: Key('auto_flag_indicator_${report.id}'),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(AppRadius.xs),
                                        border: Border.all(color: Colors.red.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Auto-Flagged Threshold Reached (${report.jobReportCount} distinct reports) → Moved to Review Queue',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Header Row: Category & Status
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        report.category.label,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      _buildStatusChip(report.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Reporter & Job Row
                                  Text(
                                    'Reporter UID: ${report.reporterUid}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  if (report.jobId != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          'Related Job: ${report.jobTitle ?? report.jobId}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        InkWell(
                                          key: Key('job_link_${report.id}'),
                                          onTap: () => context.push('/admin/jobs/${report.jobId}'),
                                          child: Text(
                                            '(View A08)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme.primary,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        if (report.jobReportCount != null) ...[
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            'Total Reports: ${report.jobReportCount}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: AppSpacing.sm),
                                  Text(report.text, style: theme.textTheme.bodyMedium),

                                  // Admin Note / Reply Preview
                                  if (report.adminNote != null) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Container(
                                      padding: const EdgeInsets.all(AppSpacing.xs),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(AppRadius.xs),
                                      ),
                                      child: Text(
                                        'Admin Reply: ${report.adminNote}',
                                        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        key: Key('update_report_btn_${report.id}'),
                                        icon: const Icon(Icons.edit_note, size: 16),
                                        label: const Text('Change Status & Reply'),
                                        onPressed: () => _openUpdateDialog(report),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
