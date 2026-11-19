// lib/features/resume/presentation/resume_upload_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/resume_repository.dart';
import '../../../data/services/resume_file_picker_service.dart';

const int kMaxResumeSizeBytes = 5 * 1024 * 1024; // 5 MB

class ResumeUploadScreen extends ConsumerStatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  ConsumerState<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends ConsumerState<ResumeUploadScreen> {
  SelectedResumeFile? _selectedFile;
  String? _validationError;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  Future<void> _pickFile() async {
    setState(() {
      _validationError = null;
      _uploadError = null;
    });

    try {
      final picker = ref.read(resumeFilePickerServiceProvider);
      final file = await picker.pickResumeFile();

      if (file == null) return;

      // 1. Extension check
      final ext = file.extension.toLowerCase();
      if (ext != 'pdf' && ext != 'docx') {
        setState(() {
          _validationError = 'Invalid file type. Only PDF and DOCX documents are supported.';
          _selectedFile = null;
        });
        return;
      }

      // 2. Size check (< 5 MB)
      if (file.size > kMaxResumeSizeBytes) {
        setState(() {
          _validationError = 'File exceeds maximum limit of 5 MB (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB).';
          _selectedFile = null;
        });
        return;
      }

      setState(() {
        _selectedFile = file;
        _validationError = null;
      });
    } catch (e) {
      setState(() {
        _validationError = 'Failed to select file: $e';
      });
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _validationError = null;
      _uploadError = null;
      _uploadProgress = 0.0;
    });
  }

  Future<void> _startUploadAndParse() async {
    final file = _selectedFile;
    if (file == null) return;

    final userUid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (userUid == null) {
      setState(() {
        _uploadError = 'Authentication error: please sign in again.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      final resumeId = 'resume_${DateTime.now().millisecondsSinceEpoch}';
      final repo = ref.read(resumeRepositoryProvider);

      // Step 1: Upload to Storage (Resumable)
      final storagePath = await repo.uploadResumeFile(
        uid: userUid,
        resumeId: resumeId,
        bytes: file.bytes,
        extension: file.extension,
        mimeType: file.mimeType,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      // Step 2: Create Firestore resumes/{id} record (UPLOADED)
      await repo.createResumeDoc(
        resumeId: resumeId,
        uid: userUid,
        storagePath: storagePath,
        fileSize: file.size,
        mimeType: file.mimeType,
      );

      // Step 3: Trigger server-side parsing callable
      await repo.parseResume(
        resumeId: resumeId,
        storagePath: storagePath,
      );

      // Step 4: Navigate to processing screen
      if (mounted) {
        context.go('${AppRoutes.resumeProcessing}?id=$resumeId');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = e.toString().contains('network') || e.toString().contains('connection')
              ? 'Upload interrupted by network loss. Tap Continue to resume.'
              : 'Failed to process resume: $e';
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final file = _selectedFile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Resume'),
        leading: BackButton(
          onPressed: _isUploading ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Upload your latest CV or resume in PDF or DOCX format. Our server-side parser will extract your information for your review.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Validation Error Banner
              if (_validationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: colorScheme.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Upload Error Banner
              if (_uploadError != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, color: colorScheme.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _uploadError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Empty Picker Area
              if (file == null)
                Expanded(
                  child: Center(
                    child: InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        height: 240,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file_rounded,
                              size: 48,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Tap to select your resume',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'PDF or DOCX (maximum 5 MB)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                // Selected File Card
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      file.extension == 'pdf'
                                          ? Icons.picture_as_pdf_rounded
                                          : Icons.description_rounded,
                                      color: colorScheme.primary,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          file.name,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${file.extension.toUpperCase()} • ${_formatFileSize(file.size)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_isUploading) ...[
                                const SizedBox(height: AppSpacing.lg),
                                LinearProgressIndicator(
                                  value: _uploadProgress > 0 ? _uploadProgress : null,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Uploading: ${(_uploadProgress * 100).toInt()}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.sync_rounded, size: 18),
                                    label: const Text('Replace'),
                                    onPressed: _isUploading ? null : _pickFile,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    label: const Text('Remove'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: colorScheme.error,
                                    ),
                                    onPressed: _isUploading ? null : _removeFile,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Buttons
              if (file != null)
                AppButton(
                  label: _isUploading ? 'Uploading...' : 'Continue',
                  isLoading: _isUploading,
                  onPressed: _isUploading ? null : _startUploadAndParse,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
