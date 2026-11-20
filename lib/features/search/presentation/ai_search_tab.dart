// lib/features/search/presentation/ai_search_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/skeleton_list.dart';
import '../../../data/models/job.dart';
import '../../../data/models/job_query.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/jobs_repository.dart';
import '../../../data/repositories/search_repository.dart';
import '../../jobs/presentation/widgets/job_card.dart';

class AiSearchTab extends ConsumerStatefulWidget {
  const AiSearchTab({super.key});

  @override
  ConsumerState<AiSearchTab> createState() => _AiSearchTabState();
}

class _AiSearchTabState extends ConsumerState<AiSearchTab> {
  final _promptController = TextEditingController();
  bool _isInterpreting = false;
  bool _isExecuting = false;
  bool _hasExecuted = false;
  String? _fallbackNotice;
  int? _remainingQuota;

  JobQuery? _interpretedQuery;
  List<Job> _jobs = [];

  final List<String> _examplePrompts = [
    'Java developer jobs in Kolkata for freshers',
    'Remote marketing internships',
  ];

  @override
  void initState() {
    super.initState();
    _loadRemainingQuota();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadRemainingQuota() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      final quota = await ref
          .read(searchRepositoryProvider)
          .getRemainingAiQuota(user.uid);
      if (mounted) {
        setState(() => _remainingQuota = quota);
      }
    }
  }

  Future<void> _interpretQuery([String? promptOverride]) async {
    final text = (promptOverride ?? _promptController.text).trim();
    if (text.isEmpty) return;

    if (promptOverride != null) {
      _promptController.text = promptOverride;
    }

    setState(() {
      _isInterpreting = true;
      _fallbackNotice = null;
    });

    final user = ref.read(authStateProvider).valueOrNull;
    final result = await ref
        .read(searchRepositoryProvider)
        .parseQuery(text, uid: user?.uid);

    if (mounted) {
      setState(() {
        _isInterpreting = false;
        _interpretedQuery = result.query;
        _fallbackNotice = result.fallbackNotice;
        if (result.remainingQuota != null) {
          _remainingQuota = result.remainingQuota;
        }
      });

      // If fallback, execute keyword search immediately as per spec
      if (result.query.fallback) {
        _runSearch();
      }
    }
  }

  Future<void> _runSearch() async {
    final query = _interpretedQuery ??
        JobQuery(
          keyword: _promptController.text.trim(),
          isAiInterpreted: false,
        );

    setState(() {
      _isExecuting = true;
      _hasExecuted = true;
    });

    try {
      final paged =
          await ref.read(jobsRepositoryProvider).queryJobs(query, pageSize: 20);
      if (mounted) {
        setState(() {
          _jobs = paged.items;
          _isExecuting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _jobs = [];
          _isExecuting = false;
        });
      }
    }
  }

  void _removeTitle(String title) {
    if (_interpretedQuery == null) return;
    final updated = List<String>.from(_interpretedQuery!.titles)..remove(title);
    setState(() {
      _interpretedQuery = _interpretedQuery!.copyWith(titles: updated);
    });
  }

  void _removeSkill(String skill) {
    if (_interpretedQuery == null) return;
    final updated = List<String>.from(_interpretedQuery!.skills)..remove(skill);
    setState(() {
      _interpretedQuery = _interpretedQuery!.copyWith(skills: updated);
    });
  }

  void _editFilterDialog({
    required String label,
    required String currentValue,
    required void Function(String newVal) onSave,
    required VoidCallback onRemove,
  }) {
    final editController = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          key: const Key('edit_filter_text_field'),
          controller: editController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('remove_filter_btn'),
            onPressed: () {
              Navigator.of(ctx).pop();
              onRemove();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            key: const Key('save_filter_btn'),
            onPressed: () {
              final val = editController.text.trim();
              Navigator.of(ctx).pop();
              if (val.isNotEmpty) {
                onSave(val);
              } else {
                onRemove();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // AI Prompt Input Container
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prompt Input Field
              TextField(
                key: const Key('ai_search_input'),
                controller: _promptController,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Describe your dream job in plain English...',
                  prefixIcon: Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  suffixIcon: _isInterpreting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          key: const Key('ai_interpret_btn'),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          tooltip: 'Interpret with AI',
                          onPressed: () => _interpretQuery(),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onSubmitted: (_) => _interpretQuery(),
              ),

              const SizedBox(height: AppSpacing.xs),

              // Soft Daily Quota Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Try an example:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Remaining AI searches today: ${_remainingQuota ?? 20}/20',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Example Prompts Chips
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                children: _examplePrompts.map((example) {
                  return ActionChip(
                    key: Key('example_chip_${example.hashCode}'),
                    avatar: const Icon(Icons.tips_and_updates_outlined, size: 14),
                    label: Text(example, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _interpretQuery(example),
                  );
                }).toList(),
              ),

              // Fallback Notice Banner
              if (_fallbackNotice != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  key: const Key('ai_fallback_notice'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _fallbackNotice!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Interpreted Filter Chips Section
              if (_interpretedQuery != null && _interpretedQuery!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'AI Interpretation',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Tap to edit, (x) to remove',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 4,
                  children: [
                    // Title chips
                    for (final title in _interpretedQuery!.titles)
                      InputChip(
                        key: Key('filter_chip_title_$title'),
                        label: Text('Role: $title'),
                        onDeleted: () => _removeTitle(title),
                        onPressed: () => _editFilterDialog(
                          label: 'Role Title',
                          currentValue: title,
                          onSave: (newVal) {
                            final titles = List<String>.from(_interpretedQuery!.titles)
                              ..remove(title)
                              ..add(newVal);
                            setState(() {
                              _interpretedQuery = _interpretedQuery!.copyWith(titles: titles);
                            });
                          },
                          onRemove: () => _removeTitle(title),
                        ),
                      ),
                    // Skill chips
                    for (final skill in _interpretedQuery!.skills)
                      InputChip(
                        key: Key('filter_chip_skill_$skill'),
                        label: Text('Skill: $skill'),
                        onDeleted: () => _removeSkill(skill),
                        onPressed: () => _editFilterDialog(
                          label: 'Skill',
                          currentValue: skill,
                          onSave: (newVal) {
                            final skills = List<String>.from(_interpretedQuery!.skills)
                              ..remove(skill)
                              ..add(newVal);
                            setState(() {
                              _interpretedQuery = _interpretedQuery!.copyWith(skills: skills);
                            });
                          },
                          onRemove: () => _removeSkill(skill),
                        ),
                      ),
                    // City chip
                    if (_interpretedQuery!.city != null)
                      InputChip(
                        key: Key('filter_chip_city_${_interpretedQuery!.city}'),
                        label: Text('City: ${_interpretedQuery!.city}'),
                        onDeleted: () => setState(() => _interpretedQuery =
                            _interpretedQuery!.copyWith(clearCity: true)),
                        onPressed: () => _editFilterDialog(
                          label: 'City',
                          currentValue: _interpretedQuery!.city!,
                          onSave: (newVal) => setState(() =>
                              _interpretedQuery = _interpretedQuery!.copyWith(city: newVal)),
                          onRemove: () => setState(() =>
                              _interpretedQuery = _interpretedQuery!.copyWith(clearCity: true)),
                        ),
                      ),
                    // Work mode chip
                    if (_interpretedQuery!.workMode != null)
                      InputChip(
                        key: Key('filter_chip_workmode_${_interpretedQuery!.workMode}'),
                        label: Text('Mode: ${_interpretedQuery!.workMode}'),
                        onDeleted: () => setState(() => _interpretedQuery =
                            _interpretedQuery!.copyWith(clearWorkMode: true)),
                        onPressed: () => _editFilterDialog(
                          label: 'Work Mode',
                          currentValue: _interpretedQuery!.workMode!,
                          onSave: (newVal) => setState(() =>
                              _interpretedQuery = _interpretedQuery!.copyWith(workMode: newVal)),
                          onRemove: () => setState(() =>
                              _interpretedQuery = _interpretedQuery!.copyWith(clearWorkMode: true)),
                        ),
                      ),
                    // Experience level chip
                    if (_interpretedQuery!.experienceLevel != null)
                      InputChip(
                        key: Key('filter_chip_exp_${_interpretedQuery!.experienceLevel}'),
                        label: Text('Exp: ${_interpretedQuery!.experienceLevel}'),
                        onDeleted: () => setState(() => _interpretedQuery =
                            _interpretedQuery!.copyWith(clearExperienceLevel: true)),
                        onPressed: () => _editFilterDialog(
                          label: 'Experience Level',
                          currentValue: _interpretedQuery!.experienceLevel!,
                          onSave: (newVal) => setState(() => _interpretedQuery =
                              _interpretedQuery!.copyWith(experienceLevel: newVal)),
                          onRemove: () => setState(() => _interpretedQuery =
                              _interpretedQuery!.copyWith(clearExperienceLevel: true)),
                        ),
                      ),
                    // Category chip
                    if (_interpretedQuery!.category != null)
                      InputChip(
                        key: Key('filter_chip_category_${_interpretedQuery!.category}'),
                        label: Text('Category: ${_interpretedQuery!.category}'),
                        onDeleted: () => setState(() => _interpretedQuery =
                            _interpretedQuery!.copyWith(clearCategory: true)),
                        onPressed: () => _editFilterDialog(
                          label: 'Category',
                          currentValue: _interpretedQuery!.category!,
                          onSave: (newVal) => setState(() =>
                              _interpretedQuery = _interpretedQuery!.copyWith(category: newVal)),
                          onRemove: () => setState(() =>
                              _interpretedQuery = _interpretedQuery!.copyWith(clearCategory: true)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Run Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('run_ai_search_btn'),
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Run Search in Verified Jobs'),
                    onPressed: _isExecuting ? null : _runSearch,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Results Section
        Expanded(
          child: _isExecuting
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SkeletonList(itemCount: 4),
                )
              : !_hasExecuted
                  ? const Center(
                      child: EmptyStateWidget(
                        icon: Icons.auto_awesome,
                        title: 'AI-Powered Search',
                        subtitle:
                            'Enter natural language requirements to extract skills, locations, and roles. Results are always fetched securely from verified Firestore jobs.',
                      ),
                    )
                  : _jobs.isEmpty
                      ? const Center(
                          child: EmptyStateWidget(
                            icon: Icons.work_off_outlined,
                            title: 'No Matching Jobs Found',
                            subtitle:
                                'Try removing some filters above or adjusting your search parameters.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          itemCount: _jobs.length,
                          itemBuilder: (context, index) {
                            return JobCard(job: _jobs[index]);
                          },
                        ),
        ),
      ],
    );
  }
}
