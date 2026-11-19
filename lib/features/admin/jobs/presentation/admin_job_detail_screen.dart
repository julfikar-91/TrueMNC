// lib/features/admin/jobs/presentation/admin_job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/admin_job.dart';
import '../../../../data/models/job_validation_model.dart';
import '../../../../data/repositories/admin_repository.dart';

/// Provider for a single AdminJob document.
final adminJobDetailProvider =
    StreamProvider.family<AdminJob?, String>((ref, id) {
  return ref.watch(adminRepositoryProvider).watchAdminJob(id);
});

/// Provider for validation records for this job.
final jobValidationsProvider =
    StreamProvider.family<List<JobValidationModel>, String>((ref, id) {
  return ref.watch(adminRepositoryProvider).watchJobValidations(id);
});

class AdminJobDetailScreen extends ConsumerWidget {
  const AdminJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Job Posting?'),
        content: const Text(
          'This will publish this job as ACTIVE and VERIFIED for all users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(adminRepositoryProvider).adminApproveJob(jobId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job approved and published as ACTIVE.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReasonInputDialog(
        title: 'Reject Job Posting',
        hint: 'Reason for rejection (e.g. invalid domain, spam keywords)...',
        confirmLabel: 'Reject',
        isDestructive: true,
      ),
    );

    if (reason != null && reason.trim().length >= 3 && context.mounted) {
      try {
        await ref.read(adminRepositoryProvider).adminRejectJob(jobId, reason);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job marked as REJECTED.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleClose(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReasonInputDialog(
        title: 'Close Job Posting',
        hint: 'Closing reason (optional: position filled, expired feed)...',
        confirmLabel: 'Close Job',
        isDestructive: true,
        allowEmpty: true,
      ),
    );

    if (reason != null && context.mounted) {
      try {
        await ref
            .read(adminRepositoryProvider)
            .adminCloseJob(jobId, reason.isEmpty ? null : reason);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job closed.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleMarkDuplicate(BuildContext context, WidgetRef ref) async {
    final canonicalId = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReasonInputDialog(
        title: 'Mark as Duplicate',
        hint: 'Enter Canonical Job ID (optional)...',
        confirmLabel: 'Mark Duplicate',
        isDestructive: false,
        allowEmpty: true,
      ),
    );

    if (canonicalId != null && context.mounted) {
      try {
        await ref.read(adminRepositoryProvider).adminMarkDuplicate(
              jobId,
              canonicalId.isEmpty ? null : canonicalId,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job marked as DUPLICATE.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleReverify(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Re-evaluating verification rules R1-R8...')),
      );
      final res =
          await ref.read(adminRepositoryProvider).adminReverifyJob(jobId);
      final allPass = res['allPass'] == true;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allPass
                  ? 'All rules passed! Job verified.'
                  : 'Rules re-evaluated: Flagged for review.',
            ),
            backgroundColor: allPass ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Re-verify failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRerunAi(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Re-running Gemini AI extraction...')),
      );
      await ref.read(adminRepositoryProvider).adminRerunExtraction(jobId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI extraction re-run succeeded.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI extraction failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobAsync = ref.watch(adminJobDetailProvider(jobId));
    final validationsAsync = ref.watch(jobValidationsProvider(jobId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Job Inspection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-verify Rules',
            onPressed: () => _handleReverify(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Re-run AI Extraction',
            onPressed: () => _handleRerunAi(context, ref),
          ),
        ],
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text('Error loading job: $err'),
          ),
        ),
        data: (adminJob) {
          if (adminJob == null) {
            return const Center(child: Text('Job posting not found.'));
          }

          final job = adminJob.job;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(job.status.name.toUpperCase()),
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${job.companyName} • ID: ${adminJob.id}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              job.isVerified
                                  ? Icons.verified
                                  : Icons.warning_amber_rounded,
                              size: 16,
                              color: job.isVerified ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              job.isVerified
                                  ? 'Verified Corporate Role'
                                  : 'Unverified / Pending Review',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: job.isVerified
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Last verified: ${_formatDate(job.verification.checkedAt)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Side-by-side or stacked diff view
                Text(
                  'Data Comparison (Original Feed vs Gemini Extraction)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Diff Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title diff
                        _DiffRow(
                          label: 'Job Title',
                          original: job.title,
                          aiExtracted: job.title,
                        ),
                        const Divider(),

                        // Category & Job Type
                        _DiffRow(
                          label: 'Category & Type',
                          original: 'Not structured in raw feed',
                          aiExtracted:
                              '${job.category ?? "General"} • ${job.jobType.name.toUpperCase()}',
                        ),
                        const Divider(),

                        // Location
                        _DiffRow(
                          label: 'Location / WorkMode',
                          original: job.location,
                          aiExtracted:
                              '${job.city ?? "Unspecified"} (${job.workMode.name})',
                        ),
                        const Divider(),

                        // Apply URL
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Official Application URL:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              job.applyUrl,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),

                        // Skills
                        Text(
                          'Extracted Skills (Canonicalized):',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ...job.requiredSkills.map(
                              (s) => Chip(
                                label: Text(s, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                              ),
                            ),
                            ...job.preferredSkills.map(
                              (s) => Chip(
                                label: Text('$s (pref)',
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Original Description vs AI Summary
                Text(
                  'Job Descriptions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // AI Summary Card
                Card(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 16, color: Colors.purple),
                            const SizedBox(width: 6),
                            Text(
                              'AI Summary',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          job.aiSummary ?? 'No summary available.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Original Description Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Original Description (Raw HTML Sanitized)',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          job.description,
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Validation History (R1-R8)
                Text(
                  'Validation History (R1-R8 Rules)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                validationsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error loading validations: $e'),
                  data: (validations) {
                    if (validations.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Text('No validation runs logged for this job.'),
                        ),
                      );
                    }
                    return Column(
                      children: validations.map((v) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: ExpansionTile(
                            leading: Icon(
                              v.allPass ? Icons.check_circle : Icons.warning,
                              color: v.allPass ? Colors.green : Colors.orange,
                            ),
                            title: Text(
                              '${v.allPass ? "PASSED" : "FAILED"} • ${_formatDate(v.timestamp)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('Reasons: ${v.reasonCodes.isEmpty ? "None" : v.reasonCodes.join(", ")}'),
                            children: v.results.map((r) {
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  r.isPass ? Icons.check : Icons.close,
                                  color: r.isPass ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                title: Text(r.ruleCode),
                                subtitle: r.details != null ? Text(r.details!) : null,
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Duplicate Hash & Dedupe Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deduplication & Integrity Key',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          'Dedupe Key: ${adminJob.id}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (adminJob.contentHash != null)
                          SelectableText(
                            'Content Hash: ${adminJob.contentHash}',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (adminJob.canonicalJobId != null)
                          SelectableText(
                            'Canonical ID: ${adminJob.canonicalJobId}',
                            style: const TextStyle(color: Colors.purple),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Action Buttons
                Text('Admin Actions', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ElevatedButton.icon(
                      key: const Key('admin_approve_btn'),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handleApprove(context, ref),
                    ),
                    ElevatedButton.icon(
                      key: const Key('admin_reject_btn'),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handleReject(context, ref),
                    ),
                    OutlinedButton.icon(
                      key: const Key('admin_close_btn'),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Close Job'),
                      onPressed: () => _handleClose(context, ref),
                    ),
                    OutlinedButton.icon(
                      key: const Key('admin_duplicate_btn'),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Mark Duplicate'),
                      onPressed: () => _handleMarkDuplicate(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.label,
    required this.original,
    required this.aiExtracted,
  });

  final String label;
  final String original;
  final String aiExtracted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text('Raw: $original', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Extracted: $aiExtracted',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReasonInputDialog extends StatefulWidget {
  const _ReasonInputDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.isDestructive,
    this.allowEmpty = false,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final bool isDestructive;
  final bool allowEmpty;

  @override
  State<_ReasonInputDialog> createState() => _ReasonInputDialogState();
}

class _ReasonInputDialogState extends State<_ReasonInputDialog> {
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
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('reason_input_field'),
          controller: _ctrl,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: widget.allowEmpty ? 'Notes (Optional)' : 'Reason (Required)',
            hintText: widget.hint,
            border: const OutlineInputBorder(),
          ),
          validator: (val) {
            if (!widget.allowEmpty && (val == null || val.trim().length < 3)) {
              return 'Reason is required (min 3 characters)';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('confirm_reason_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDestructive ? Colors.red : null,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_ctrl.text.trim());
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
