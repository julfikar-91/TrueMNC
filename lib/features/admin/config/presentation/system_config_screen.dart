// lib/features/admin/config/presentation/system_config_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../providers/system_config_providers.dart';

class SystemConfigScreen extends ConsumerStatefulWidget {
  const SystemConfigScreen({super.key});

  @override
  ConsumerState<SystemConfigScreen> createState() => _SystemConfigScreenState();
}

class _SystemConfigScreenState extends ConsumerState<SystemConfigScreen> {
  // Scoring weights
  int _skills = 40;
  int _education = 15;
  int _experience = 15;
  int _location = 10;
  int _preference = 20;

  // Thresholds
  int _threshold = 55;
  int _softCap = 74;
  int _excellentCutoff = 80;
  int _goodCutoff = 65;
  int _fairCutoff = 55;

  // Notification caps
  int _maxPushesPerDay = 3;
  final _quietStartController = TextEditingController(text: '22:00');
  final _quietEndController = TextEditingController(text: '08:00');
  final _timezoneController = TextEditingController(text: 'Asia/Kolkata');

  // AI Model Names
  final _geminiMatchController = TextEditingController(text: 'gemini-1.5-pro');
  final _geminiSummaryController =
      TextEditingController(text: 'gemini-1.5-flash');
  final _geminiParserController = TextEditingController(text: 'gemini-1.5-pro');

  // Minimum App Version
  final _minAppVersionController = TextEditingController(text: '1.0.0');

  // Feature Flags
  bool _enableAiScoring = true;
  bool _enableJobAlerts = true;
  bool _enableCompanyVerification = true;
  bool _enableResumeParsing = true;
  bool _enableDirectApply = true;
  bool _maintenanceMode = false;

  bool _isSaving = false;
  bool _isInitializedFromRemote = false;

  int get _totalWeight =>
      _skills + _education + _experience + _location + _preference;

  bool get _isTotalWeightValid => _totalWeight == 100;

  @override
  void dispose() {
    _quietStartController.dispose();
    _quietEndController.dispose();
    _timezoneController.dispose();
    _geminiMatchController.dispose();
    _geminiSummaryController.dispose();
    _geminiParserController.dispose();
    _minAppVersionController.dispose();
    super.dispose();
  }

  void _loadRemoteConfig(
    Map<String, dynamic> scoring,
    Map<String, dynamic> app,
  ) {
    if (_isInitializedFromRemote) return;
    _isInitializedFromRemote = true;

    if (scoring.isNotEmpty) {
      final weights = scoring['weights'] as Map<String, dynamic>?;
      if (weights != null) {
        _skills = (weights['skills'] as num?)?.toInt() ?? _skills;
        _education = (weights['education'] as num?)?.toInt() ?? _education;
        _experience = (weights['experience'] as num?)?.toInt() ?? _experience;
        _location = (weights['location'] as num?)?.toInt() ?? _location;
        _preference = (weights['preference'] as num?)?.toInt() ?? _preference;
      }
      _threshold = (scoring['threshold'] as num?)?.toInt() ?? _threshold;
      _softCap = (scoring['softCap'] as num?)?.toInt() ?? _softCap;

      final cutoffs = scoring['labelCutoffs'] as Map<String, dynamic>?;
      if (cutoffs != null) {
        _excellentCutoff =
            (cutoffs['excellent'] as num?)?.toInt() ?? _excellentCutoff;
        _goodCutoff = (cutoffs['good'] as num?)?.toInt() ?? _goodCutoff;
        _fairCutoff = (cutoffs['fair'] as num?)?.toInt() ?? _fairCutoff;
      }
    }

    if (app.isNotEmpty) {
      _minAppVersionController.text =
          app['minAppVersion']?.toString() ?? _minAppVersionController.text;
      _maintenanceMode = app['maintenanceMode'] as bool? ?? _maintenanceMode;

      final flags = app['featureFlags'] as Map<String, dynamic>?;
      if (flags != null) {
        _enableAiScoring =
            flags['enableAiScoring'] as bool? ?? _enableAiScoring;
        _enableJobAlerts =
            flags['enableJobAlerts'] as bool? ?? _enableJobAlerts;
        _enableCompanyVerification =
            flags['enableCompanyVerification'] as bool? ??
                _enableCompanyVerification;
        _enableResumeParsing =
            flags['enableResumeParsing'] as bool? ?? _enableResumeParsing;
        _enableDirectApply =
            flags['enableDirectApply'] as bool? ?? _enableDirectApply;
      }

      final notifs = app['notifications'] as Map<String, dynamic>?;
      if (notifs != null) {
        _maxPushesPerDay =
            (notifs['maxPushesPerDay'] as num?)?.toInt() ?? _maxPushesPerDay;
        final quiet = notifs['quietHours'] as Map<String, dynamic>?;
        if (quiet != null) {
          _quietStartController.text =
              quiet['start']?.toString() ?? _quietStartController.text;
          _quietEndController.text =
              quiet['end']?.toString() ?? _quietEndController.text;
          _timezoneController.text =
              quiet['timezone']?.toString() ?? _timezoneController.text;
        }
      }

      final models = app['aiModels'] as Map<String, dynamic>?;
      if (models != null) {
        _geminiMatchController.text = models['geminiMatchModel']?.toString() ??
            _geminiMatchController.text;
        _geminiSummaryController.text =
            models['geminiSummaryModel']?.toString() ??
                _geminiSummaryController.text;
        _geminiParserController.text =
            models['geminiParserModel']?.toString() ??
                _geminiParserController.text;
      }
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_isTotalWeightValid) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final adminRepo = ref.read(adminRepositoryProvider);

      // 1. Save scoring config
      await adminRepo.updateScoringConfig({
        'weights': {
          'skills': _skills,
          'education': _education,
          'experience': _experience,
          'location': _location,
          'preference': _preference,
        },
        'threshold': _threshold,
        'softCap': _softCap,
        'labelCutoffs': {
          'excellent': _excellentCutoff,
          'good': _goodCutoff,
          'fair': _fairCutoff,
        },
      });

      // 2. Save app config
      await adminRepo.updateAppConfig({
        'minAppVersion': _minAppVersionController.text.trim(),
        'maintenanceMode': _maintenanceMode,
        'featureFlags': {
          'enableAiScoring': _enableAiScoring,
          'enableJobAlerts': _enableJobAlerts,
          'enableCompanyVerification': _enableCompanyVerification,
          'enableResumeParsing': _enableResumeParsing,
          'enableDirectApply': _enableDirectApply,
        },
        'notifications': {
          'maxPushesPerDay': _maxPushesPerDay,
          'quietHours': {
            'start': _quietStartController.text.trim(),
            'end': _quietEndController.text.trim(),
            'timezone': _timezoneController.text.trim(),
          },
        },
        'aiModels': {
          'geminiMatchModel': _geminiMatchController.text.trim(),
          'geminiSummaryModel': _geminiSummaryController.text.trim(),
          'geminiParserModel': _geminiParserController.text.trim(),
        },
      });

      ref.invalidate(configVersionsProvider('app'));
      ref.invalidate(configVersionsProvider('scoring_v1'));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'System configuration saved successfully. New version snapshot recorded.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppException
          ? e.message
          : e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save Failed'),
          content: Text(msg),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showVersionHistoryBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _VersionHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Watch remote configs to auto-fill once
    final scoringAsync = ref.watch(scoringConfigStreamProvider);
    final appAsync = ref.watch(appConfigStreamProvider);

    if (scoringAsync.hasValue && appAsync.hasValue) {
      _loadRemoteConfig(
        scoringAsync.value ?? {},
        appAsync.value ?? {},
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Version History',
            onPressed: _showVersionHistoryBottomSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SCORING WEIGHTS CARD ──────────────────────────────────────────
            _buildScoringWeightsCard(theme),
            const SizedBox(height: AppSpacing.md),

            // ── THRESHOLDS & CAP CARD ─────────────────────────────────────────
            _buildThresholdsCard(theme),
            const SizedBox(height: AppSpacing.md),

            // ── NOTIFICATIONS CARD ────────────────────────────────────────────
            _buildNotificationsCard(theme),
            const SizedBox(height: AppSpacing.md),

            // ── AI MODEL NAMES CARD ───────────────────────────────────────────
            _buildAiModelsCard(theme),
            const SizedBox(height: AppSpacing.md),

            // ── FEATURE FLAGS & MAINTENANCE CARD ──────────────────────────────
            _buildFeatureFlagsCard(theme),
            const SizedBox(height: AppSpacing.md),

            // ── MIN APP VERSION CARD ──────────────────────────────────────────
            _buildAppVersionCard(theme),
            const SizedBox(height: AppSpacing.xl),

            // ── SAVE BUTTON ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                key: const Key('save_config_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: (!_isTotalWeightValid || _isSaving)
                    ? null
                    : _saveConfiguration,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : _isTotalWeightValid
                          ? 'Save Configuration'
                          : 'Save Disabled (Weights != 100%)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildScoringWeightsCard(ThemeData theme) {
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
            Row(
              children: [
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Scoring Weights (Must Total 100%)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── LIVE TOTAL WEIGHT INDICATOR ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: _isTotalWeightValid
                    ? AppColors.success.withOpacity(0.12)
                    : theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: _isTotalWeightValid
                      ? AppColors.success
                      : theme.colorScheme.error,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isTotalWeightValid
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    color: _isTotalWeightValid
                        ? AppColors.success
                        : theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _isTotalWeightValid
                          ? 'Weights Total: 100% / 100% (Valid)'
                          : 'Weights Total: $_totalWeight% / 100% (Must equal exactly 100%)',
                      style: TextStyle(
                        color: _isTotalWeightValid
                            ? AppColors.success
                            : theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Weight Sliders
            _weightSlider('Skills Weight', _skills, (val) {
              setState(() => _skills = val);
            }),
            _weightSlider('Education Weight', _education, (val) {
              setState(() => _education = val);
            }),
            _weightSlider('Experience Weight', _experience, (val) {
              setState(() => _experience = val);
            }),
            _weightSlider('Location Weight', _location, (val) {
              setState(() => _location = val);
            }),
            _weightSlider('Career Preference Weight', _preference, (val) {
              setState(() => _preference = val);
            }),
          ],
        ),
      ),
    );
  }

  Widget _weightSlider(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label: $value%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 5,
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$value%',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdsCard(ThemeData theme) {
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
            Row(
              children: [
                Icon(Icons.analytics_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Matching Thresholds & Cutoffs',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _weightSlider('Match Threshold', _threshold, (v) {
              setState(() => _threshold = v);
            }),
            _weightSlider('Soft Cap', _softCap, (v) {
              setState(() => _softCap = v);
            }),
            const Divider(height: AppSpacing.lg),
            Text(
              'Label Cutoffs',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _weightSlider('Excellent Cutoff', _excellentCutoff, (v) {
              setState(() => _excellentCutoff = v);
            }),
            _weightSlider('Good Cutoff', _goodCutoff, (v) {
              setState(() => _goodCutoff = v);
            }),
            _weightSlider('Fair Cutoff', _fairCutoff, (v) {
              setState(() => _fairCutoff = v);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard(ThemeData theme) {
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
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Notification Caps & Quiet Hours',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Max Pushes Per Day: $_maxPushesPerDay',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _maxPushesPerDay > 0
                      ? () => setState(() => _maxPushesPerDay--)
                      : null,
                ),
                Text(
                  '$_maxPushesPerDay',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _maxPushesPerDay++),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quietStartController,
                    decoration: const InputDecoration(
                      labelText: 'Quiet Hours Start',
                      hintText: '22:00',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _quietEndController,
                    decoration: const InputDecoration(
                      labelText: 'Quiet Hours End',
                      hintText: '08:00',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _timezoneController,
              decoration: const InputDecoration(
                labelText: 'Timezone',
                hintText: 'Asia/Kolkata',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiModelsCard(ThemeData theme) {
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
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'AI Model Names (Server Config)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _geminiMatchController,
              decoration: const InputDecoration(
                labelText: 'Match Model',
                hintText: 'gemini-1.5-pro',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _geminiSummaryController,
              decoration: const InputDecoration(
                labelText: 'Job Summary Model',
                hintText: 'gemini-1.5-flash',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _geminiParserController,
              decoration: const InputDecoration(
                labelText: 'Resume Parser Model',
                hintText: 'gemini-1.5-pro',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureFlagsCard(ThemeData theme) {
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
            Row(
              children: [
                Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Feature Flags & Maintenance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              title: const Text('AI Match Scoring'),
              value: _enableAiScoring,
              onChanged: (v) => setState(() => _enableAiScoring = v),
            ),
            SwitchListTile(
              title: const Text('Job Push Alerts'),
              value: _enableJobAlerts,
              onChanged: (v) => setState(() => _enableJobAlerts = v),
            ),
            SwitchListTile(
              title: const Text('Company Verification Requirement'),
              value: _enableCompanyVerification,
              onChanged: (v) => setState(() => _enableCompanyVerification = v),
            ),
            SwitchListTile(
              title: const Text('Resume Parsing'),
              value: _enableResumeParsing,
              onChanged: (v) => setState(() => _enableResumeParsing = v),
            ),
            SwitchListTile(
              title: const Text('Direct Apply Integration'),
              value: _enableDirectApply,
              onChanged: (v) => setState(() => _enableDirectApply = v),
            ),
            SwitchListTile(
              title: const Text('Maintenance Mode (Block Users)'),
              value: _maintenanceMode,
              activeThumbColor: theme.colorScheme.error,
              onChanged: (v) => setState(() => _maintenanceMode = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppVersionCard(ThemeData theme) {
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
            Row(
              children: [
                Icon(Icons.system_update_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Minimum Supported App Version',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _minAppVersionController,
              decoration: const InputDecoration(
                labelText: 'Minimum App Version',
                hintText: '1.0.0',
                helperText:
                    'Clients below this version will be forced to update.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionHistorySheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appVersionsAsync = ref.watch(configVersionsProvider('app'));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  'Configuration Version History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: appVersionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Failed to load version history: $e'),
                ),
                data: (versions) {
                  if (versions.isEmpty) {
                    return const Center(
                      child: Text(
                        'No previous version snapshots found. Saving creates the first history record.',
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    itemCount: versions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final v = versions[index];
                      final versionId = v['id'] ?? 'v$index';
                      final changedBy = v['changedBy'] ?? 'Unknown admin';
                      final timestamp = v['timestamp']?.toString() ?? 'Recent';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text('${index + 1}'),
                        ),
                        title: Text('Snapshot $versionId'),
                        subtitle: Text(
                          'Changed by: $changedBy\nTimestamp: $timestamp',
                          style: theme.textTheme.bodySmall,
                        ),
                        isThreeLine: true,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
