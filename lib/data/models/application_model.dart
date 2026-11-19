// lib/data/models/application_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'application_model.freezed.dart';
part 'application_model.g.dart';

enum ApplicationStatus { submitted, reviewing, shortlisted, rejected, hired }

@freezed
class ApplicationModel with _$ApplicationModel {
  const factory ApplicationModel({
    required String id,
    required String jobId,
    required String userId,
    required String companyId,
    @Default(ApplicationStatus.submitted) ApplicationStatus status,
    String? coverLetter,
    String? resumeUrl,
    DateTime? appliedAt,
    DateTime? updatedAt,
    // AI score — set server-side only
    double? matchScore,
  }) = _ApplicationModel;

  factory ApplicationModel.fromJson(Map<String, dynamic> json) =>
      _$ApplicationModelFromJson(json);
}
