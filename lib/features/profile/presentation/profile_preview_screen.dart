// lib/features/profile/presentation/profile_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/field_value_wrapper.dart';
import '../../../data/models/resume_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/resume_repository.dart';

class ProfilePreviewScreen extends ConsumerStatefulWidget {
  const ProfilePreviewScreen({super.key, this.resumeId});

  final String? resumeId;

  @override
  ConsumerState<ProfilePreviewScreen> createState() =>
      _ProfilePreviewScreenState();
}

class _ProfilePreviewScreenState extends ConsumerState<ProfilePreviewScreen> {
  ParsedResumeDraft? _localDraft;
  final Set<String> _acceptedInferredFieldKeys = {};
  bool? _isFresherAnswer; // null = unanswered, false = has experience, true = fresher
  bool _isConfirming = false;
  String? _confirmError;

  void _initLocalDraft(ParsedResumeDraft serverDraft) {
    if (_localDraft == null) {
      _localDraft = serverDraft;
      final totalExp =
          serverDraft.experience.totalExperienceStated.value?.toString().toLowerCase() ?? '';
      if (totalExp.contains('fresher') || totalExp == '0') {
        _isFresherAnswer = true;
      }
    }
  }

  void _acceptInferredField(String key) {
    setState(() {
      _acceptedInferredFieldKeys.add(key);
    });
  }

  Future<void> _handleConfirmProfile(String resumeId) async {
    final draft = _localDraft;
    if (draft == null) return;

    if (draft.experience.items.isEmpty && _isFresherAnswer == null) {
      setState(() {
        _confirmError = 'Please specify if you have work experience or are a fresher.';
      });
      return;
    }

    setState(() {
      _isConfirming = true;
      _confirmError = null;
    });

    try {
      final repo = ref.read(resumeRepositoryProvider);
      final finalizedDraft = _buildFinalizedDraft(draft);

      await repo.confirmProfile(
        resumeId: resumeId,
        confirmedProfile: finalizedDraft.toMap(),
      );

      ref.invalidate(userDocProvider);

      if (mounted) {
        final userDoc = ref.read(userDocProvider).valueOrNull;
        if (userDoc?.preferencesMissing == true) {
          context.go(AppRoutes.preferences);
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
          _confirmError = 'Failed to confirm profile: $e. Your edits have been saved locally.';
        });
      }
    }
  }

  ParsedResumeDraft _buildFinalizedDraft(ParsedResumeDraft source) {
    FieldValueWrapper<T> finalizeField<T>(String key, FieldValueWrapper<T> field) {
      if (field.provenance == Provenance.inferred) {
        if (_acceptedInferredFieldKeys.contains(key)) {
          return field.copyWith(provenance: Provenance.explicit);
        } else {
          return field.copyWith(value: null, provenance: Provenance.missing);
        }
      }
      return field;
    }

    final p = source.personal;
    final finalizedPersonal = p.copyWith(
      name: finalizeField('personal.name', p.name),
      email: finalizeField('personal.email', p.email),
      phone: finalizeField('personal.phone', p.phone),
      location: finalizeField('personal.location', p.location),
      linkedin: finalizeField('personal.linkedin', p.linkedin),
      github: finalizeField('personal.github', p.github),
      portfolio: finalizeField('personal.portfolio', p.portfolio),
    );

    FieldValueWrapper<Object> expStated = source.experience.totalExperienceStated;
    if (_isFresherAnswer == true) {
      expStated = const FieldValueWrapper(
        value: 'Fresher (0 years)',
        provenance: Provenance.explicit,
        confidence: 1.0,
      );
    }

    return source.copyWith(
      personal: finalizedPersonal,
      experience: source.experience.copyWith(
        totalExperienceStated: expStated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveResumeId = widget.resumeId ??
        ref.watch(userDocProvider).valueOrNull?.toMap()['current_resume_id'] as String? ??
        '';

    if (effectiveResumeId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Preview')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, size: 48),
              const SizedBox(height: AppSpacing.md),
              const Text('No resume preview found.'),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Upload Resume',
                onPressed: () => context.go(AppRoutes.resumeUpload),
              ),
            ],
          ),
        ),
      );
    }

    final parseAsync = ref.watch(watchResumeParseProvider(effectiveResumeId));

    return parseAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Review Profile')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Review Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 54, color: colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text('Error loading profile draft', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(err.toString(), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(watchResumeParseProvider(effectiveResumeId)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (serverDraft) {
        if (serverDraft == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Review Profile')),
            body: const Center(child: Text('Profile draft is not ready yet.')),
          );
        }

        _initLocalDraft(serverDraft);
        final draft = _localDraft ?? serverDraft;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Review Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete Resume',
                onPressed: () => _confirmDeleteResume(effectiveResumeId),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Confirm Profile',
                isLoading: _isConfirming,
                onPressed: _isConfirming ? null : () => _handleConfirmProfile(effectiveResumeId),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Mandatory Header Review Banner
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: colorScheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Please review your AI-generated profile before continuing.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // PARTIAL Status / Extraction Warnings
                if (draft.status == 'PARTIAL' || draft.warnings.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.error),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Attention Required',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ...draft.warnings.map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '• $w',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Error Message if Confirmation Failed
                if (_confirmError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _confirmError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 2. Personal Section
                _buildSectionCard(
                  title: 'Personal Information',
                  icon: Icons.person_outline_rounded,
                  onEdit: () => _showEditPersonalDialog(draft.personal),
                  child: Column(
                    children: [
                      _buildFieldRow('Name', draft.personal.name, 'personal.name'),
                      _buildFieldRow('Email', draft.personal.email, 'personal.email'),
                      _buildFieldRow('Phone', draft.personal.phone, 'personal.phone'),
                      _buildFieldRow('Location', draft.personal.location, 'personal.location'),
                      _buildFieldRow('LinkedIn', draft.personal.linkedin, 'personal.linkedin'),
                      _buildFieldRow('GitHub', draft.personal.github, 'personal.github'),
                      _buildFieldRow('Portfolio', draft.personal.portfolio, 'personal.portfolio'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. Summary Section
                _buildSectionCard(
                  title: 'Professional Summary',
                  icon: Icons.short_text_rounded,
                  onEdit: () => _showEditSummaryDialog(draft.summary),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              draft.summary.value ?? 'No summary extracted',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: draft.summary.value == null
                                    ? colorScheme.outline
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          _buildProvenanceBadge(draft.summary.provenance),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 4. Skills Section
                _buildSectionCard(
                  title: 'Technical & Soft Skills',
                  icon: Icons.code_rounded,
                  onEdit: () => _showEditSkillsDialog(draft.skills),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkillsCategory('Languages', draft.skills.languages),
                      _buildSkillsCategory('Frameworks', draft.skills.frameworks),
                      _buildSkillsCategory('Databases', draft.skills.databases),
                      _buildSkillsCategory('Cloud & DevOps', draft.skills.cloud),
                      _buildSkillsCategory('Tools & Platforms', draft.skills.tools),
                      _buildSkillsCategory('Soft Skills', draft.skills.soft),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 5. Work Experience Section
                _buildSectionCard(
                  title: 'Work Experience',
                  icon: Icons.work_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (draft.experience.items.isNotEmpty) ...[
                        ...draft.experience.items.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.title.value ?? "Role"} at ${item.company.value ?? "Company"}',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      _buildProvenanceBadge(item.company.provenance),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.startDate.value ?? ""} - ${item.isCurrent.value == true ? "Present" : (item.endDate.value ?? "")}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                  if (item.description.value != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description.value!,
                                      style: theme.textTheme.bodySmall,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            )),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isFresherAnswer == null
                                  ? colorScheme.tertiary
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.help_outline_rounded,
                                      color: colorScheme.tertiary),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'Do you have work experience?',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'No previous employment was detected on your resume. Please specify your status:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      label: const Center(child: Text('I am a Fresher')),
                                      selected: _isFresherAnswer == true,
                                      onSelected: (selected) {
                                        setState(() {
                                          _isFresherAnswer = selected ? true : null;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: ChoiceChip(
                                      label: const Center(child: Text('I have Experience')),
                                      selected: _isFresherAnswer == false,
                                      onSelected: (selected) {
                                        setState(() {
                                          _isFresherAnswer = selected ? false : null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 6. Education Section
                _buildSectionCard(
                  title: 'Education',
                  icon: Icons.school_outlined,
                  child: Column(
                    children: [
                      if (draft.education.isEmpty)
                        Text(
                          'No education items extracted',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                        )
                      else
                        ...draft.education.map((edu) => Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${edu.degree.value ?? "Degree"} - ${edu.specialization.value ?? ""}',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${edu.institution.value ?? ""} (${edu.graduationYear.value ?? ""})',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildProvenanceBadge(edu.degree.provenance),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 7. Projects Section
                if (draft.projects.isNotEmpty) ...[
                  _buildSectionCard(
                    title: 'Projects',
                    icon: Icons.terminal_rounded,
                    child: Column(
                      children: [
                        for (final p in draft.projects)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(p.title.value ?? 'Project'),
                            subtitle: Text(p.description.value ?? '', maxLines: 2),
                            trailing: _buildProvenanceBadge(p.title.provenance),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 8. Certifications Section
                if (draft.certifications.isNotEmpty) ...[
                  _buildSectionCard(
                    title: 'Certifications',
                    icon: Icons.workspace_premium_outlined,
                    child: Column(
                      children: [
                        for (final c in draft.certifications)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.name.value ?? 'Certification'),
                            subtitle: Text(c.issuer.value ?? ''),
                            trailing: _buildProvenanceBadge(c.name.provenance),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    VoidCallback? onEdit,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit $title',
                    onPressed: onEdit,
                  ),
              ],
            ),
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, FieldValueWrapper<String> field, String fieldKey) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInferred = field.provenance == Provenance.inferred;
    final isAccepted = _acceptedInferredFieldKeys.contains(fieldKey);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(isInferred ? AppSpacing.sm : 0),
      decoration: isInferred
          ? BoxDecoration(
              color: isAccepted
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                  : Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isAccepted ? Colors.green : Colors.amber,
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              field.value ?? 'Missing',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: field.value == null
                    ? colorScheme.outline
                    : colorScheme.onSurface,
                fontStyle: field.value == null ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildProvenanceBadge(field.provenance),
          if (isInferred && !isAccepted && field.value != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              tooltip: 'Accept inferred value',
              onPressed: () => _acceptInferredField(fieldKey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProvenanceBadge(Provenance provenance) {
    final (label, icon, color) = switch (provenance) {
      Provenance.explicit => ('Extracted', Icons.check_circle_outline, Colors.green),
      Provenance.inferred => ('Needs confirmation', Icons.help_outline_rounded, Colors.amber.shade800),
      Provenance.missing => ('Missing', Icons.remove_circle_outline_rounded, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCategory(String title, List<FieldValueWrapper<String>> list) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (list.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: list
                .where((s) => s.value != null)
                .map((s) => Chip(
                      label: Text(s.value!),
                      labelStyle: const TextStyle(fontSize: 12),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _showEditPersonalDialog(PersonalDraft current) {
    final nameCtrl = TextEditingController(text: current.name.value);
    final emailCtrl = TextEditingController(text: current.email.value);
    final phoneCtrl = TextEditingController(text: current.phone.value);
    final locationCtrl = TextEditingController(text: current.location.value);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Personal Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Location'),
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
            onPressed: () {
              setState(() {
                _localDraft = _localDraft?.copyWith(
                  personal: current.copyWith(
                    name: current.name.copyWith(
                      value: nameCtrl.text.trim(),
                      provenance: Provenance.explicit,
                    ),
                    email: current.email.copyWith(
                      value: emailCtrl.text.trim(),
                      provenance: Provenance.explicit,
                    ),
                    phone: current.phone.copyWith(
                      value: phoneCtrl.text.trim(),
                      provenance: Provenance.explicit,
                    ),
                    location: current.location.copyWith(
                      value: locationCtrl.text.trim(),
                      provenance: Provenance.explicit,
                    ),
                  ),
                );
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditSummaryDialog(FieldValueWrapper<String> summary) {
    final ctrl = TextEditingController(text: summary.value);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Professional Summary'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Summary',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _localDraft = _localDraft?.copyWith(
                  summary: summary.copyWith(
                    value: ctrl.text.trim(),
                    provenance: Provenance.explicit,
                  ),
                );
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditSkillsDialog(SkillsDraft current) {
    final ctrl = TextEditingController(
      text: current.languages.map((l) => l.value).where((v) => v != null).join(', '),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Languages'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Languages (comma separated)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newLanguages = ctrl.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .map((s) => FieldValueWrapper<String>(
                        value: s,
                        provenance: Provenance.explicit,
                        confidence: 1.0,
                      ))
                  .toList();

              setState(() {
                _localDraft = _localDraft?.copyWith(
                  skills: SkillsDraft(
                    languages: newLanguages,
                    frameworks: current.frameworks,
                    libraries: current.libraries,
                    databases: current.databases,
                    cloud: current.cloud,
                    tools: current.tools,
                    technicalCerts: current.technicalCerts,
                    soft: current.soft,
                  ),
                );
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteResume(String resumeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resume?'),
        content: const Text(
          'This will remove your resume file and parsed draft from the server. You can upload a new resume at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(resumeRepositoryProvider).deleteResume(resumeId);
        if (mounted) {
          context.go(AppRoutes.resumeUpload);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete resume: $e')),
          );
        }
      }
    }
  }
}
