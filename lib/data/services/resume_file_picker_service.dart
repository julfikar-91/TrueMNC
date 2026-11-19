// lib/data/services/resume_file_picker_service.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedResumeFile {
  const SelectedResumeFile({
    required this.name,
    required this.bytes,
    required this.size,
    required this.extension,
    this.path,
  });

  final String name;
  final Uint8List bytes;
  final int size;
  final String extension;
  final String? path;

  String get mimeType => switch (extension.toLowerCase()) {
        'pdf' => 'application/pdf',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        _ => 'application/octet-stream',
      };
}

abstract class ResumeFilePickerService {
  Future<SelectedResumeFile?> pickResumeFile();
}

class DefaultResumeFilePickerService implements ResumeFilePickerService {
  const DefaultResumeFilePickerService();

  @override
  Future<SelectedResumeFile?> pickResumeFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
    );

    if (file == null) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final size = await file.length() ?? bytes.length;
    final ext = file.extension?.toLowerCase() ?? '';

    return SelectedResumeFile(
      name: file.name,
      bytes: bytes,
      size: size,
      extension: ext,
      path: file.path,
    );
  }
}

final resumeFilePickerServiceProvider = Provider<ResumeFilePickerService>((ref) {
  return const DefaultResumeFilePickerService();
});
