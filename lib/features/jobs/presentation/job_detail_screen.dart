// lib/features/jobs/presentation/job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/job.dart';
import '../../../data/repositories/jobs_repository.dart';

/// Provider for a single public job.
final publicJobProvider = FutureProvider.family<Job?, String>((ref, id) {
  return ref.watch(jobsRepositoryProvider).getById(id);
});

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _isRedirecting = false;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleApply(Job job) async {
    setState(() => _isRedirecting = true);

    try {
      final applyUrl =
          await ref.read(jobsRepositoryProvider).recordRedirect(widget.jobId);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.verified, color: Colors.green),
                const SizedBox(width: AppSpacing.sm),
                const Text('Verified Application'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This position has been verified directly on the official company careers portal.',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Company: ${job.companyName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Role: ${job.title}'),
                const SizedBox(height: AppSpacing.sm),
                const Text('Official URL:'),
                SelectableText(
                  applyUrl,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRedirecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jobAsync = ref.watch(publicJobProvider(widget.jobId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () {},
          ),
        ],
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: AppSpacing.sm),
                Text('Failed to load job: $err'),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(publicJobProvider(widget.jobId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (job) {
          if (job == null) {
            return const Center(child: Text('Position not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Card with Verification Badge
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Verification Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'Official Company Job • Verified ${_formatDate(job.verification.checkedAt)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        Text(
                          job.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.companyName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tags row: Category, Workmode, Location
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (job.category != null)
                              Chip(
                                label: Text(job.category!),
                                visualDensity: VisualDensity.compact,
                              ),
                            Chip(
                              label: Text(job.workMode.name.toUpperCase()),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (job.location.isNotEmpty)
                              Chip(
                                avatar: const Icon(Icons.location_on, size: 14),
                                label: Text(job.location),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (job.deadline != null)
                              Chip(
                                avatar: const Icon(Icons.calendar_today, size: 14),
                                label: Text('Closes ${_formatDate(job.deadline)}'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. AI Summary Card (Prominently Labelled)
                if (job.aiSummary != null && job.aiSummary!.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
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
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            job.aiSummary!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 3. Skills Required Card
                if (job.requiredSkills.isNotEmpty ||
                    job.preferredSkills.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Required Skills',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ...job.requiredSkills.map(
                                (s) => Chip(
                                  label: Text(s),
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                ),
                              ),
                              ...job.preferredSkills.map(
                                (s) => Chip(
                                  label: Text('$s (Preferred)'),
                                  backgroundColor: theme
                                      .colorScheme.surfaceContainerHighest,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 4. Job Description Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Role Description',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          job.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: ElevatedButton.icon(
            key: const Key('apply_official_btn'),
            icon: _isRedirecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.open_in_new),
            label: Text(
              _isRedirecting
                  ? 'Verifying Application Link...'
                  : 'Apply on Official Website',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: _isRedirecting
                ? null
                : () {
                    final job = jobAsync.valueOrNull;
                    if (job != null) _handleApply(job);
                  },
          ),
        ),
      ),
    );
  }
}
