// lib/features/admin/review/presentation/review_queue_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/admin_job.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/auth_repository.dart';

/// Provider for review queue jobs (status == PENDING_REVIEW).
final reviewQueueProvider = StreamProvider.autoDispose<List<AdminJob>>((ref) {
  return ref.watch(adminRepositoryProvider).watchReviewQueue();
});

class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queueAsync = ref.watch(reviewQueueProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Review Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Queue',
            onPressed: () => ref.invalidate(reviewQueueProvider),
          ),
        ],
      ),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: AppSpacing.sm),
                Text('Failed to load review queue: $err'),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(reviewQueueProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (queue) {
          if (queue.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Review queue is clear',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'All collected jobs have been verified or resolved.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: queue.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final adminJob = queue[index];
              return _ReviewQueueItemCard(
                adminJob: adminJob,
                currentUid: currentUid,
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewQueueItemCard extends ConsumerWidget {
  const _ReviewQueueItemCard({
    required this.adminJob,
    required this.currentUid,
  });

  final AdminJob adminJob;
  final String currentUid;

  String _cleanReason(String code) {
    return switch (code) {
      'R2_DOMAIN_FAILED' => 'Domain mismatch',
      'R3_URL_FAILED' => 'Dead apply URL',
      'R4_REQUIRED_FIELDS_MISSING' => 'Missing fields',
      'R5_EXPIRED_OR_STALE' => 'Expired or stale',
      'R6_DUPLICATE_KEY_COLLISION' => 'Possible duplicate',
      'R7_AI_CONFIDENCE_LOW' => 'Low AI confidence',
      'R7_AI_SCHEMA_INVALID' => 'AI extraction failed',
      'R8_SAFETY_VIOLATION' => 'Safety violation',
      _ => code,
    };
  }

  Future<void> _claimAndReview(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminRepositoryProvider).claimReviewItem(adminJob.id);
      if (context.mounted) {
        context.push('/admin/jobs/${adminJob.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminRepositoryProvider).adminApproveJob(adminJob.id);
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
          SnackBar(content: Text('Approve failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReviewReasonDialog(
        title: 'Reject Job Posting',
        actionLabel: 'Reject',
        isDestructive: true,
      ),
    );

    if (reason != null && reason.trim().length >= 3 && context.mounted) {
      try {
        await ref
            .read(adminRepositoryProvider)
            .adminRejectJob(adminJob.id, reason.trim());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job rejected.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reject failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleRequestChanges(
      BuildContext context, WidgetRef ref) async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReviewReasonDialog(
        title: 'Request Changes',
        actionLabel: 'Request Changes',
        isDestructive: false,
      ),
    );

    if (note != null && note.trim().length >= 3 && context.mounted) {
      try {
        await ref
            .read(adminRepositoryProvider)
            .adminRequestChanges(adminJob.id, note.trim());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Changes requested.')),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLocked = adminJob.isLockedByOther(currentUid);
    final remainingSec = adminJob.reviewClaim?.remainingSeconds ?? 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isLocked
              ? Colors.orange.withOpacity(0.8)
              : theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: isLocked ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Soft-lock banner if claimed by another admin
            if (isLocked) ...[
              Container(
                key: const Key('soft_lock_banner'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Being reviewed by another admin (Lock expires in ${remainingSec}s)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Title & Company
            Row(
              children: [
                Expanded(
                  child: Text(
                    adminJob.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: const Text('Pending Review', style: TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.orange.withOpacity(0.15),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${adminJob.companyName} • ${adminJob.job.location.isNotEmpty ? adminJob.job.location : "Remote"}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),

            // Reason chips (Why it landed in review queue)
            Text(
              'Review Reasons:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: adminJob.reviewReasons.isEmpty
                  ? [
                      const Chip(
                        label: Text('Manual review requested',
                            style: TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]
                  : adminJob.reviewReasons.map((code) {
                      return Chip(
                        avatar: const Icon(Icons.error_outline,
                            size: 14, color: Colors.red),
                        label: Text(
                          _cleanReason(code),
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.red.withOpacity(0.08),
                      );
                    }).toList(),
            ),

            if (adminJob.adminReviewNote != null) ...[
              const SizedBox(height: 6),
              Text(
                'Previous Admin Note: ${adminJob.adminReviewNote}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],

            const Divider(height: 20),

            // Actions row: Approve / Reject / Request changes / Inspect
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ElevatedButton.icon(
                  key: Key('queue_approve_${adminJob.id}'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLocked ? null : () => _handleApprove(context, ref),
                ),
                ElevatedButton.icon(
                  key: Key('queue_reject_${adminJob.id}'),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLocked ? null : () => _handleReject(context, ref),
                ),
                OutlinedButton.icon(
                  key: Key('queue_changes_${adminJob.id}'),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Request Changes'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: isLocked
                      ? null
                      : () => _handleRequestChanges(context, ref),
                ),
                TextButton.icon(
                  key: Key('queue_inspect_${adminJob.id}'),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Full Inspection'),
                  onPressed: () => _claimAndReview(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewReasonDialog extends StatefulWidget {
  const _ReviewReasonDialog({
    required this.title,
    required this.actionLabel,
    required this.isDestructive,
  });

  final String title;
  final String actionLabel;
  final bool isDestructive;

  @override
  State<_ReviewReasonDialog> createState() => _ReviewReasonDialogState();
}

class _ReviewReasonDialogState extends State<_ReviewReasonDialog> {
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
          key: const Key('review_reason_input'),
          controller: _ctrl,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: '${widget.actionLabel} Reason (Required)',
            hintText: 'Enter reason or feedback for review logs...',
            border: const OutlineInputBorder(),
          ),
          validator: (val) {
            if (val == null || val.trim().length < 3) {
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
          key: const Key('confirm_review_reason_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDestructive ? Colors.red : null,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_ctrl.text.trim());
            }
          },
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
