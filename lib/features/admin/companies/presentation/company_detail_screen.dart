// lib/features/admin/companies/presentation/company_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/models/company.dart';
import '../../../../data/models/company_source.dart';
import '../../../../data/models/collection_run_model.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../core/theme/app_spacing.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

/// Watches a single [Company] document in real-time by its Firestore id.
final watchCompanyProvider = StreamProvider.family<Company?, String>((ref, id) {
  return ref.read(companyRepositoryProvider).watchById(id);
});

/// Watches sources for this company.
final companySourcesForDetailProvider =
    StreamProvider.family<List<CompanySource>, String>((ref, id) {
  return ref.watch(adminRepositoryProvider).watchCompanySources(id);
});

/// Watches collection runs for this company.
final companyRunsForDetailProvider =
    StreamProvider.family<List<CollectionRunModel>, String>((ref, id) {
  return ref.watch(adminRepositoryProvider).watchCollectionRuns(companyId: id, limit: 10);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class CompanyDetailScreen extends ConsumerWidget {
  const CompanyDetailScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(watchCompanyProvider(companyId));

    return companyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Company Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Failed to load company: $err',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (company) {
        if (company == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Company Details')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_outlined, size: 48),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Company not found'),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return _CompanyDetailView(company: company);
      },
    );
  }
}

// ── Main view (data present) ─────────────────────────────────────────────────

class _CompanyDetailView extends ConsumerWidget {
  const _CompanyDetailView({required this.company});

  final Company company;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDisable(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable Company?'),
        content: const Text(
          'This will hide all jobs from this company. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(adminRepositoryProvider).upsertCompany({
        'id': company.id,
        'isActive': false,
      });
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(company.name),
        leading: const BackButton(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/admin/companies/${company.id}/edit'),
        child: const Icon(Icons.edit_outlined),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Header Card ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32, // 64dp diameter
                      backgroundImage: company.logoUrl != null
                          ? NetworkImage(company.logoUrl!)
                          : null,
                      child: company.logoUrl == null
                          ? Text(
                              _initials(company.name),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                      backgroundColor: colorScheme.primaryContainer,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      company.name,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (company.isVerified)
                      Chip(
                        avatar: Icon(
                          Icons.verified,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        label: const Text('Verified'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            colorScheme.primaryContainer.withOpacity(0.5),
                      )
                    else
                      Chip(
                        avatar: Icon(
                          Icons.pending_outlined,
                          size: 16,
                          color: colorScheme.secondary,
                        ),
                        label: const Text('Unverified'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            colorScheme.secondaryContainer.withOpacity(0.5),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── 2. Info Section ─────────────────────────────────────────────
            Card(
              child: Column(
                children: [
                  // Domain / slug
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: const Text('Domain'),
                    subtitle: Text(company.slug ?? '—'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Career Page
                  ListTile(
                    leading: const Icon(Icons.work_outline),
                    title: const Text('Career Page'),
                    subtitle: company.careersUrl != null
                        ? GestureDetector(
                            onTap: () {
                              // URL launching handled by url_launcher if
                              // available; left as a no-op placeholder here
                              // so the tile is visually tappable.
                            },
                            child: Text(
                              company.careersUrl!,
                              style: TextStyle(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          )
                        : const Text('—'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Website
                  ListTile(
                    leading: const Icon(Icons.public_outlined),
                    title: const Text('Website'),
                    subtitle: company.website != null
                        ? GestureDetector(
                            onTap: () {
                              // URL launching handled by url_launcher if
                              // available; left as a no-op placeholder here.
                            },
                            child: Text(
                              company.website!,
                              style: TextStyle(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          )
                        : const Text('—'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Active Jobs (placeholder)
                  const ListTile(
                    leading: Icon(Icons.business_center_outlined),
                    title: Text('Active Jobs'),
                    subtitle: Text('0 active jobs'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Last Collection
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Last Collection'),
                    subtitle: Text(_formatDate(company.updatedAt)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── 3. Sources Section ──────────────────────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final sourcesAsync = ref.watch(companySourcesForDetailProvider(company.id ?? ''));
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Sources', style: theme.textTheme.titleMedium),
                            TextButton.icon(
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text('Manage Sources'),
                              onPressed: () => context.push('/admin/companies/${company.id}/sources'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        sourcesAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          ),
                          error: (e, _) => Text('Error loading sources: $e',
                              style: TextStyle(color: colorScheme.error)),
                          data: (sources) {
                            if (sources.isEmpty) {
                              return Text(
                                'No sources configured yet. Click Manage Sources to add Greenhouse, Lever, or careers feed.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.secondary,
                                ),
                              );
                            }
                            return Column(
                              children: sources.map((s) {
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    s.isVerified ? Icons.verified : Icons.warning_amber_rounded,
                                    color: s.isVerified ? Colors.green : Colors.orange,
                                  ),
                                  title: Text('${s.type} (${s.enabled ? "Active" : "Disabled"})'),
                                  subtitle: Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Text('${s.intervalMin}m'),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── 4. Collection History ───────────────────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final runsAsync = ref.watch(companyRunsForDetailProvider(company.id ?? ''));
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Collection History', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        runsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          ),
                          error: (e, _) => Text('Error loading history: $e',
                              style: TextStyle(color: colorScheme.error)),
                          data: (runs) {
                            if (runs.isEmpty) {
                              return Text(
                                'No collection runs recorded yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.secondary,
                                ),
                              );
                            }
                            return Column(
                              children: runs.map((r) {
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    r.isSuccess
                                        ? Icons.check_circle_outline
                                        : r.isFailed
                                            ? Icons.error_outline
                                            : Icons.sync,
                                    color: r.isSuccess
                                        ? Colors.green
                                        : r.isFailed
                                            ? Colors.red
                                            : Colors.blue,
                                  ),
                                  title: Text('${r.status} - ${r.jobsFound} found (${r.jobsCreated} new, ${r.jobsUpdated} updated)'),
                                  subtitle: Text(_formatDate(r.startedAt)),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── 5. Action Buttons ───────────────────────────────────────────

            // Disable Company
            ElevatedButton(
              onPressed: () => _confirmDisable(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Disable Company'),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Run Collection Now (Wired)
            Consumer(
              builder: (context, ref, _) {
                final sourcesAsync = ref.watch(companySourcesForDetailProvider(company.id ?? ''));
                final sources = sourcesAsync.valueOrNull ?? [];
                final hasSource = sources.isNotEmpty;

                return ElevatedButton.icon(
                  key: const Key('run_collection_now_btn'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Collection Now'),
                  onPressed: hasSource
                      ? () async {
                          final sourceId = sources.first.id;
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Triggering collection...')),
                            );
                            await ref.read(adminRepositoryProvider).adminRunCollectionNow(sourceId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Collection completed successfully.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Collection failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                );
              },
            ),

            // Extra bottom padding so FAB doesn't obscure buttons
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
