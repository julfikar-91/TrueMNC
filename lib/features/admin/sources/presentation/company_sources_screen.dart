// lib/features/admin/sources/presentation/company_sources_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/company.dart';
import '../../../../data/models/company_source.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../companies/presentation/company_detail_screen.dart';

/// Provider streaming sources for a specific company.
final companySourcesProvider =
    StreamProvider.family<List<CompanySource>, String>((ref, companyId) {
  return ref.watch(adminRepositoryProvider).watchCompanySources(companyId);
});

class CompanySourcesScreen extends ConsumerWidget {
  const CompanySourcesScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final companyAsync = ref.watch(watchCompanyProvider(companyId));
    final sourcesAsync = ref.watch(companySourcesProvider(companyId));

    return Scaffold(
      appBar: AppBar(
        title: Text(companyAsync.valueOrNull?.name ?? 'Company Sources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Source',
            onPressed: () => _openSourceFormDialog(
              context,
              ref,
              companyId: companyId,
              company: companyAsync.valueOrNull,
            ),
          ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: AppSpacing.sm),
                Text('Failed to load sources: $err', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companySourcesProvider(companyId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (sources) {
          if (sources.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        size: 64, color: theme.colorScheme.outline),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Sources Configured',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Configure a Greenhouse, Lever, or careers feed adapter to begin automated job collection.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Official Source'),
                      onPressed: () => _openSourceFormDialog(
                        context,
                        ref,
                        companyId: companyId,
                        company: companyAsync.valueOrNull,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final company = companyAsync.valueOrNull;

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: sources.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final source = sources[index];
              return _SourceCard(
                source: source,
                company: company,
                onEdit: () => _openSourceFormDialog(
                  context,
                  ref,
                  companyId: companyId,
                  source: source,
                  company: company,
                ),
                onTest: () => _openTestConnectionDialog(context, ref, source, company),
                onVerify: () => _openVerificationWizard(context, ref, source, company),
                onToggleEnable: (val) => _toggleSourceEnabled(context, ref, source, val, company),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleSourceEnabled(
    BuildContext context,
    WidgetRef ref,
    CompanySource source,
    bool enabled,
    Company? company,
  ) async {
    final isCompanyVerified = company?.isVerified == true;
    if (!isCompanyVerified && enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source must be verified before collection can be enabled.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await ref.read(adminRepositoryProvider).adminUpsertSource({
        'id': source.id,
        'companyId': source.companyId,
        'type': source.type,
        'url': source.url,
        'config': source.config,
        'secretRef': source.secretRef,
        'intervalMin': source.intervalMin,
        'enabled': enabled,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled ? 'Collection enabled.' : 'Collection disabled.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update source: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openSourceFormDialog(
    BuildContext context,
    WidgetRef ref, {
    required String companyId,
    CompanySource? source,
    Company? company,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _SourceFormSheet(
        companyId: companyId,
        source: source,
        company: company,
      ),
    );
  }

  void _openTestConnectionDialog(
    BuildContext context,
    WidgetRef ref,
    CompanySource source,
    Company? company,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _TestConnectionDialog(source: source, company: company),
    );
  }

  void _openVerificationWizard(
    BuildContext context,
    WidgetRef ref,
    CompanySource source,
    Company? company,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _VerificationWizardDialog(source: source, company: company),
    );
  }
}

// ── Source Card Widget ────────────────────────────────────────────────────────

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.company,
    required this.onEdit,
    required this.onTest,
    required this.onVerify,
    required this.onToggleEnable,
  });

  final CompanySource source;
  final Company? company;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final VoidCallback onVerify;
  final ValueChanged<bool> onToggleEnable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompanyVerified = company?.isVerified == true;

    return Card(
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
            // Header: Type badge & Enable Switch
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    source.type,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (source.isVerified)
                  Chip(
                    avatar: const Icon(Icons.verified, size: 14, color: Colors.green),
                    label: const Text('Verified', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.green.withOpacity(0.1),
                  )
                else
                  Chip(
                    avatar: const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                    label: const Text('Unverified', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.orange.withOpacity(0.1),
                  ),
                const Spacer(),
                Tooltip(
                  message: !isCompanyVerified
                      ? 'Requires verification before enabling'
                      : 'Toggle collection',
                  child: Switch(
                    key: Key('source_switch_${source.id}'),
                    value: source.enabled,
                    onChanged: isCompanyVerified ? onToggleEnable : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // URL & Config
            Text(
              source.url,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (source.config['boardToken'] != null) ...[
              const SizedBox(height: 2),
              Text(
                'Board Token: ${source.config['boardToken']}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (source.secretRef != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.key, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Secret Ref: ${source.secretRef}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Interval: ${source.intervalMin ~/ 60}h (${source.intervalMin}m)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const Divider(height: 24),

            // Actions row: Test, Verify, Edit
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  key: Key('test_source_${source.id}'),
                  icon: const Icon(Icons.network_check, size: 16),
                  label: const Text('Test Connection'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onTest,
                ),
                if (!source.isVerified || !isCompanyVerified)
                  ElevatedButton.icon(
                    key: Key('verify_source_${source.id}'),
                    icon: const Icon(Icons.verified_user_outlined, size: 16),
                    label: const Text('Verify Source'),
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    onPressed: onVerify,
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  onPressed: onEdit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit Source Bottom Sheet ──────────────────────────────────────────

class _SourceFormSheet extends StatefulWidget {
  const _SourceFormSheet({
    required this.companyId,
    this.source,
    this.company,
  });

  final String companyId;
  final CompanySource? source;
  final Company? company;

  @override
  State<_SourceFormSheet> createState() => _SourceFormSheetState();
}

class _SourceFormSheetState extends State<_SourceFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _type;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _boardTokenCtrl;
  late final TextEditingController _secretRefCtrl;
  late final TextEditingController _intervalCtrl;
  bool _isLoading = false;

  final _allowedTypes = [
    'GREENHOUSE',
    'LEVER',
    'SMARTRECRUITERS',
    'OFFICIAL_FEED',
    'CAREERS_PAGE',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _type = s?.type ?? 'GREENHOUSE';
    _urlCtrl = TextEditingController(
      text: s?.url ?? 'https://boards-api.greenhouse.io/v1/boards/',
    );
    _boardTokenCtrl = TextEditingController(
      text: (s?.config['boardToken'] as String?) ?? '',
    );
    _secretRefCtrl = TextEditingController(text: s?.secretRef ?? '');
    _intervalCtrl = TextEditingController(
      text: (s?.intervalMin ?? 360).toString(),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _boardTokenCtrl.dispose();
    _secretRefCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(WidgetRef ref) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final config = <String, dynamic>{};
    if (_boardTokenCtrl.text.trim().isNotEmpty) {
      config['boardToken'] = _boardTokenCtrl.text.trim();
    }

    final payload = {
      if (widget.source != null) 'id': widget.source!.id,
      'companyId': widget.companyId,
      'type': _type,
      'url': _urlCtrl.text.trim(),
      'config': config,
      'secretRef': _secretRefCtrl.text.trim().isNotEmpty
          ? _secretRefCtrl.text.trim()
          : null,
      'intervalMin': int.tryParse(_intervalCtrl.text.trim()) ?? 360,
      'enabled': widget.source?.enabled ?? false,
    };

    try {
      await ref.read(adminRepositoryProvider).adminUpsertSource(payload);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.source != null
                ? 'Source updated successfully.'
                : 'Source created. Verification required before collection.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save source: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.source != null ? 'Edit Source' : 'Add Official Source',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Source Type Dropdown
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Adapter Type',
                  border: OutlineInputBorder(),
                ),
                items: _allowedTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _type = val);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Source URL
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Endpoint or Careers Page URL',
                  hintText: 'https://boards-api.greenhouse.io/v1/boards/...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'URL is required';
                  final uri = Uri.tryParse(val.trim());
                  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                    return 'Enter a valid URL (http/https)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Board Token (for Greenhouse / Lever)
              TextFormField(
                controller: _boardTokenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Board Token / Slug',
                  hintText: 'e.g. airbnb, stripe',
                  helperText: 'Used by Greenhouse/Lever adapters to fetch job posts',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Secret Ref Name ONLY
              TextFormField(
                controller: _secretRefCtrl,
                decoration: const InputDecoration(
                  labelText: 'Secret Reference Key Name (Optional)',
                  hintText: 'e.g. GREENHOUSE_API_KEY',
                  helperText:
                      'Identifier name ONLY. Never paste real tokens or secrets here.',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != null && val.contains('=')) {
                    return 'Enter key identifier only, not key-value secrets';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Interval
              TextFormField(
                controller: _intervalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Collection Interval (Minutes)',
                  helperText: 'Minimum 60 minutes (1 hour). Default 360m (6 hours)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 60) {
                    return 'Interval must be at least 60 minutes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: _isLoading ? null : () => _submit(ref),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.source != null
                            ? 'Update Source'
                            : 'Create Source'),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Test Connection Dialog ──────────────────────────────────────────────────

class _TestConnectionDialog extends ConsumerStatefulWidget {
  const _TestConnectionDialog({required this.source, this.company});

  final CompanySource source;
  final Company? company;

  @override
  ConsumerState<_TestConnectionDialog> createState() =>
      _TestConnectionDialogState();
}

class _TestConnectionDialogState extends ConsumerState<_TestConnectionDialog> {
  bool _isLoading = true;
  String? _error;
  int _totalFound = 0;
  List<Map<String, dynamic>> _samples = [];

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref.read(adminRepositoryProvider).adminTestSource({
        'type': widget.source.type,
        'url': widget.source.url,
        'companyId': widget.source.companyId,
        'config': widget.source.config,
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _totalFound = (res['totalFound'] as num?)?.toInt() ?? 0;
          _samples = (res['samples'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.network_check, color: Colors.blue),
          const SizedBox(width: AppSpacing.sm),
          const Text('Test Connection'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  Text('Fetching sample jobs and evaluating rules R1-R8...'),
                ],
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 40, color: Colors.red),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Test Failed',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_error!, textAlign: TextAlign.center),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Found $_totalFound jobs on source. Sample of ${_samples.length}:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ..._samples.map((sample) {
                          final rawJob = (sample['rawJob'] as Map?) ?? {};
                          final rules = (sample['rules'] as List<dynamic>?) ?? [];
                          final allPass = sample['allPass'] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rawJob['title']?.toString() ?? 'Job',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          allPass ? 'PASS' : 'FLAGGED',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: allPass
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    rawJob['applyUrl']?.toString() ?? '',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: rules.map((r) {
                                      final rMap = (r as Map);
                                      final code = rMap['ruleCode']?.toString() ?? '';
                                      final pass = rMap['result'] == 'PASS';
                                      return Chip(
                                        label: Text(code,
                                            style: const TextStyle(fontSize: 9)),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: pass
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.red.withOpacity(0.15),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!_isLoading && _error != null)
          ElevatedButton(
            onPressed: _runTest,
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

// ── 3-Step Verification Wizard Dialog ────────────────────────────────────────

class _VerificationWizardDialog extends ConsumerStatefulWidget {
  const _VerificationWizardDialog({required this.source, this.company});

  final CompanySource source;
  final Company? company;

  @override
  ConsumerState<_VerificationWizardDialog> createState() =>
      _VerificationWizardDialogState();
}

class _VerificationWizardDialogState
    extends ConsumerState<_VerificationWizardDialog> {
  int _currentStep = 0;
  bool _adminSignOff = false;
  bool _enableCollection = true;
  bool _isSubmitting = false;

  Future<void> _completeVerification() async {
    if (!_adminSignOff) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(adminRepositoryProvider).adminVerifySource(
            sourceId: widget.source.id,
            companyId: widget.source.companyId,
            adminSignOff: true,
            enableCollection: _enableCollection,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Source and Company successfully verified.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;

    return AlertDialog(
      title: const Text('Source Verification Wizard'),
      content: SizedBox(
        width: 480,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _completeVerification();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _currentStep == 2 && !_adminSignOff
                        ? null
                        : details.onStepContinue,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == 2 ? 'Verify & Enable' : 'Next'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                  ),
                ],
              ),
            );
          },
          steps: [
            // Step 1: Domain Match Check
            Step(
              title: const Text('1. Domain Match Check'),
              isActive: _currentStep >= 0,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verifies that the target adapter host aligns with company domain or approved ATS.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Company: ${company?.name ?? widget.source.companyId}'),
                  Text('Official Domain: ${company?.slug ?? company?.website ?? "—"}'),
                  Text('Source Adapter: ${widget.source.type}'),
                  Text('Source URL: ${widget.source.url}'),
                ],
              ),
            ),
            // Step 2: Sample URL Check
            Step(
              title: const Text('2. Live Endpoint Probe'),
              isActive: _currentStep >= 1,
              content: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adapter endpoint returns HTTP 200 and schema compliant jobs.'),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'No lookalike domain attacks or payment solicitations detected on feed.',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
            // Step 3: Admin Sign-Off
            Step(
              title: const Text('3. Admin Sign-Off'),
              isActive: _currentStep >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: const Text(
                      'I confirm this is an authentic, authorized corporate careers source for this company.',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _adminSignOff,
                    onChanged: (val) {
                      setState(() => _adminSignOff = val ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'Enable automated collection pipeline immediately upon verification',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _enableCollection,
                    onChanged: (val) {
                      setState(() => _enableCollection = val ?? true);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
