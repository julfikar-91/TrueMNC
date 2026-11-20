// lib/features/reports/presentation/reports_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/skeleton_list.dart';
import '../../../data/models/user_report.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/report_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({
    super.key,
    this.initialJobId,
    this.initialJobTitle,
  });

  final String? initialJobId;
  final String? initialJobTitle;

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  UserReportCategory _selectedCategory = UserReportCategory.incorrectJob;
  String? _relatedJobId;
  String? _relatedJobTitle;
  final _textController = TextEditingController();
  Uint8List? _screenshotBytes;
  String? _screenshotName;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _relatedJobId = widget.initialJobId;
    _relatedJobTitle = widget.initialJobTitle;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a report.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      String? screenshotPath;
      if (_screenshotBytes != null) {
        screenshotPath = await ref.read(reportRepositoryProvider).uploadScreenshot(
              user.uid,
              _screenshotBytes!,
              'jpg',
            );
      }

      await ref.read(reportRepositoryProvider).submitReport(
            category: _selectedCategory,
            jobId: _relatedJobId,
            text: _textController.text.trim(),
            screenshotPath: screenshotPath,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully. Thank you for helping keep TrueMNC clean!'),
          backgroundColor: AppColors.success,
        ),
      );

      _textController.clear();
      setState(() {
        _screenshotBytes = null;
        _screenshotName = null;
        _isSubmitting = false;
      });

      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception:', '').trim();
      setState(() {
        _isSubmitting = false;
        _errorMessage = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(key: Key('submit_report_tab_header'), text: 'Submit Report'),
            Tab(key: Key('my_reports_tab_header'), text: 'My Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Submit Report ──────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prefilled Related Job Header if present
                  if (_relatedJobId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.work_outline, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Related Job',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  _relatedJobTitle ?? _relatedJobId!,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _relatedJobId = null;
                                _relatedJobTitle = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Category Dropdown
                  Text(
                    'Category',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<UserReportCategory>(
                    key: const Key('report_category_dropdown'),
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    ),
                    items: UserReportCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Description
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Description',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _textController,
                        builder: (_, val, __) => Text(
                          '${val.text.length}/1000',
                          key: const Key('report_char_counter'),
                          style: TextStyle(
                            fontSize: 12,
                            color: val.text.length > 1000 ? Colors.red : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    key: const Key('report_description_input'),
                    controller: _textController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLines: 5,
                    maxLength: 1000,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    decoration: InputDecoration(
                      hintText: 'Please detail what is incorrect, broken, or suspicious...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 5) {
                        return 'Description must be at least 5 characters.';
                      }
                      if (val.trim().length > 1000) {
                        return 'Description cannot exceed 1000 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Optional Screenshot
                  Text(
                    'Screenshot (Optional)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (_screenshotName != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.image, color: Colors.green),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: Text(_screenshotName!, style: const TextStyle(fontSize: 12))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => setState(() {
                            _screenshotBytes = null;
                            _screenshotName = null;
                          }),
                        ),
                      ],
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      key: const Key('attach_screenshot_btn'),
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Attach Screenshot (Max 5MB)'),
                      onPressed: () {
                        // Attach mock screenshot bytes for testing & UX
                        setState(() {
                          _screenshotBytes = Uint8List.fromList([1, 2, 3, 4]);
                          _screenshotName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
                        });
                      },
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      key: const Key('report_error_banner'),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('submit_report_btn'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Report'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tab 2: My Reports ─────────────────────────────────────────────
          StreamBuilder<List<UserReport>>(
            stream: user != null
                ? ref.watch(reportRepositoryProvider).watchMyReports(user.uid)
                : Stream.value([]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SkeletonList(itemCount: 3),
                );
              }

              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return const Center(
                  child: EmptyStateWidget(
                    icon: Icons.checklist_rtl_rounded,
                    title: 'No Reports Submitted',
                    subtitle: 'Any problems or incorrect job postings you flag will appear here with resolution updates.',
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final rep = reports[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                rep.category.label,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              _buildStatusChip(rep.status),
                            ],
                          ),
                          if (rep.jobTitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Job: ${rep.jobTitle}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(rep.text, style: theme.textTheme.bodyMedium),

                          // Admin Reply Banner if present
                          if (rep.adminNote != null && rep.adminNote!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              key: Key('admin_reply_${rep.id}'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.support_agent, size: 16, color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Admin Response',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(rep.adminNote!, style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
