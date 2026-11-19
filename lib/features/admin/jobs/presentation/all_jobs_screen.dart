// lib/features/admin/jobs/presentation/all_jobs_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/admin_job.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/paged_controller.dart';

/// State parameter holder for filtering jobs.
class AdminJobFilter {
  const AdminJobFilter({
    this.companyId,
    this.category,
    this.verificationState,
    this.status,
    this.sourcePlatform,
    this.searchQuery,
    this.startDate,
    this.endDate,
  });

  final String? companyId;
  final String? category;
  final String? verificationState;
  final String? status;
  final String? sourcePlatform;
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;

  AdminJobFilter copyWith({
    String? companyId,
    String? category,
    String? verificationState,
    String? status,
    String? sourcePlatform,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return AdminJobFilter(
      companyId: companyId ?? this.companyId,
      category: category ?? this.category,
      verificationState: verificationState ?? this.verificationState,
      status: status ?? this.status,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

/// Filter provider for A07.
final adminJobFilterProvider = StateProvider<AdminJobFilter>((ref) {
  return const AdminJobFilter();
});

/// Paged controller provider for Admin Jobs.
final adminJobsPagedControllerProvider = StateNotifierProvider.autoDispose<
    PagedController<AdminJob>, PagedState<AdminJob>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  final filter = ref.watch(adminJobFilterProvider);

  return PagedController<AdminJob>(
    (cursor) => repo.listAdminJobs(
      pageSize: 20,
      startAfter: cursor,
      companyId: filter.companyId,
      category: filter.category,
      verificationState: filter.verificationState,
      status: filter.status,
      sourcePlatform: filter.sourcePlatform,
      searchQuery: filter.searchQuery,
      startDate: filter.startDate,
      endDate: filter.endDate,
    ),
  );
});

class AllJobsScreen extends ConsumerStatefulWidget {
  const AllJobsScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  ConsumerState<AllJobsScreen> createState() => _AllJobsScreenState();
}

class _AllJobsScreenState extends ConsumerState<AllJobsScreen> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedJobIds = {};
  bool _isBulkMode = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialStatus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminJobFilterProvider.notifier).update(
              (f) => f.copyWith(status: widget.initialStatus),
            );
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(adminJobsPagedControllerProvider.notifier).loadMore();
    }
  }

  void _toggleSelectJob(String id) {
    setState(() {
      if (_selectedJobIds.contains(id)) {
        _selectedJobIds.remove(id);
      } else {
        _selectedJobIds.add(id);
      }
    });
  }

  Future<void> _triggerBulkAction(String action) async {
    if (_selectedJobIds.isEmpty) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _BulkActionReasonDialog(
        action: action,
        count: _selectedJobIds.length,
      ),
    );

    if (reason != null && reason.trim().length >= 3 && mounted) {
      try {
        await ref.read(adminRepositoryProvider).adminBulkAction(
              action: action,
              jobIds: _selectedJobIds.toList(),
              reason: reason.trim(),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully processed $action for ${_selectedJobIds.length} jobs.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _selectedJobIds.clear();
            _isBulkMode = false;
          });
          ref.read(adminJobsPagedControllerProvider.notifier).refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bulk action failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(adminJobsPagedControllerProvider);
    final filter = ref.watch(adminJobFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isBulkMode
            ? '${_selectedJobIds.length} Selected'
            : 'All Corporate Jobs'),
        actions: [
          IconButton(
            icon: Icon(_isBulkMode ? Icons.close : Icons.checklist),
            tooltip: _isBulkMode ? 'Cancel Selection' : 'Bulk Actions',
            onPressed: () {
              setState(() {
                _isBulkMode = !_isBulkMode;
                if (!_isBulkMode) _selectedJobIds.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Jobs',
            onPressed: () => _openFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & active filter bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by title, company, category...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(adminJobFilterProvider.notifier).update(
                                (f) => f.copyWith(searchQuery: ''),
                              );
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onSubmitted: (val) {
                ref.read(adminJobFilterProvider.notifier).update(
                      (f) => f.copyWith(searchQuery: val.trim()),
                    );
              },
            ),
          ),

          // Active filter indicator chip
          if (filter.status != null && filter.status != 'ALL')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Chip(
                    label: Text('Status: ${filter.status}'),
                    onDeleted: () {
                      ref.read(adminJobFilterProvider.notifier).update(
                            (f) => f.copyWith(status: 'ALL'),
                          );
                    },
                  ),
                ],
              ),
            ),

          // Main list with states
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading && state.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.error != null && state.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Failed to load jobs: ${state.error}'),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton(
                            onPressed: () => ref
                                .read(adminJobsPagedControllerProvider.notifier)
                                .refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.work_off_outlined,
                              size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No Jobs Found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'No jobs match the current filters or search term.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(adminJobsPagedControllerProvider.notifier)
                        .refresh();
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.items.length + (state.isLoading && state.items.isNotEmpty ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final adminJob = state.items[index];
                      final isSelected = _selectedJobIds.contains(adminJob.id);

                      return _AdminJobCard(
                        adminJob: adminJob,
                        isBulkMode: _isBulkMode,
                        isSelected: isSelected,
                        onSelectToggle: () => _toggleSelectJob(adminJob.id),
                        onTap: () {
                          if (_isBulkMode) {
                            _toggleSelectJob(adminJob.id);
                          } else {
                            context.push('/admin/jobs/${adminJob.id}');
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Bulk action bottom bar
          if (_isBulkMode && _selectedJobIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('bulk_close_btn'),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Bulk Close'),
                        onPressed: () => _triggerBulkAction('CLOSE'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('bulk_reject_btn'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Bulk Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _triggerBulkAction('REJECT'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _JobFilterSheet(),
    );
  }
}

// ── Admin Job Card ──────────────────────────────────────────────────────────

class _AdminJobCard extends StatelessWidget {
  const _AdminJobCard({
    required this.adminJob,
    required this.isBulkMode,
    required this.isSelected,
    required this.onSelectToggle,
    required this.onTap,
  });

  final AdminJob adminJob;
  final bool isBulkMode;
  final bool isSelected;
  final VoidCallback onSelectToggle;
  final VoidCallback onTap;

  Color _statusColor(String status) {
    return switch (status.toUpperCase()) {
      'ACTIVE' => Colors.green,
      'PENDING_REVIEW' => Colors.orange,
      'REJECTED' => Colors.red,
      'CLOSED' => Colors.grey,
      'EXPIRED' => Colors.brown,
      'DUPLICATE' => Colors.purple,
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = adminJob.job.status.name.toUpperCase();
    final statusColor = _statusColor(status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBulkMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectToggle(),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            adminJob.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Company & Category
                    Text(
                      '${adminJob.companyName} • ${adminJob.job.category ?? "General"}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Verification badge & City
                    Row(
                      children: [
                        Icon(
                          adminJob.job.isVerified
                              ? Icons.verified
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: adminJob.job.isVerified
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          adminJob.job.isVerified ? 'Verified' : 'Unverified',
                          style: TextStyle(
                            fontSize: 12,
                            color: adminJob.job.isVerified
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('•'),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          adminJob.job.location.isNotEmpty
                              ? adminJob.job.location
                              : 'Remote',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bulk Action Reason Dialog ───────────────────────────────────────────────

class _BulkActionReasonDialog extends StatefulWidget {
  const _BulkActionReasonDialog({
    required this.action,
    required this.count,
  });

  final String action;
  final int count;

  @override
  State<_BulkActionReasonDialog> createState() =>
      _BulkActionReasonDialogState();
}

class _BulkActionReasonDialogState extends State<_BulkActionReasonDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bulk ${widget.action} (${widget.count} jobs)'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A mandatory reason is required for administrative audit logging.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('bulk_action_reason_field'),
              controller: _ctrl,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Audit Reason (required)',
                hintText: 'e.g. Expired role; duplicate batch; verified scam',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().length < 3) {
                  return 'Reason is required (min 3 characters)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('confirm_bulk_action_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.action == 'REJECT' ? Colors.red : null,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_ctrl.text.trim());
            }
          },
          child: Text('Confirm ${widget.action}'),
        ),
      ],
    );
  }
}

// ── Filter Sheet ────────────────────────────────────────────────────────────

class _JobFilterSheet extends ConsumerStatefulWidget {
  const _JobFilterSheet();

  @override
  ConsumerState<_JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends ConsumerState<_JobFilterSheet> {
  late String _status;
  late String _verificationState;

  final _statuses = [
    'ALL',
    'ACTIVE',
    'PENDING_REVIEW',
    'CLOSED',
    'REJECTED',
    'EXPIRED',
    'DUPLICATE',
  ];

  final _verifications = [
    'ALL',
    'VERIFIED',
    'UNVERIFIED',
    'PENDING',
    'REJECTED',
  ];

  @override
  void initState() {
    super.initState();
    final f = ref.read(adminJobFilterProvider);
    _status = f.status ?? 'ALL';
    _verificationState = f.verificationState ?? 'ALL';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filter Jobs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),

          // Status Dropdown
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(
              labelText: 'Job Status',
              border: OutlineInputBorder(),
            ),
            items: _statuses
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _status = val);
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Verification State Dropdown
          DropdownButtonFormField<String>(
            value: _verificationState,
            decoration: const InputDecoration(
              labelText: 'Verification State',
              border: OutlineInputBorder(),
            ),
            items: _verifications
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _verificationState = val);
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(adminJobFilterProvider.notifier).state =
                        const AdminJobFilter();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(adminJobFilterProvider.notifier).update(
                          (f) => f.copyWith(
                            status: _status,
                            verificationState: _verificationState,
                          ),
                        );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
