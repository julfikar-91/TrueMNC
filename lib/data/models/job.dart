// lib/data/models/job.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'timestamp_converter.dart';

part 'job.freezed.dart';
part 'job.g.dart';

// ── Job Salary ───────────────────────────────────────────────────────────────

@freezed
class JobSalary with _$JobSalary {
  const JobSalary._();

  const factory JobSalary({
    int? min,
    int? max,
    @Default('INR') String currency,
  }) = _JobSalary;

  factory JobSalary.fromJson(Map<String, dynamic> json) =>
      _$JobSalaryFromJson(json);
}

// ── Job Verification ─────────────────────────────────────────────────────────

@freezed
class JobVerification with _$JobVerification {
  const JobVerification._();

  const factory JobVerification({
    @JsonKey(unknownEnumValue: VerificationState.unverified)
    @Default(VerificationState.unverified)
    VerificationState state,
    @TimestampConverter() DateTime? checkedAt,
    @Default(<String>[]) List<String> rules,
  }) = _JobVerification;

  factory JobVerification.fromJson(Map<String, dynamic> json) =>
      _$JobVerificationFromJson(json);
}

// ── Job (Section 9 Specification) ───────────────────────────────────────────

@freezed
class Job with _$Job {
  const Job._();

  const factory Job({
    String? id,
    required String companyId,
    required String companyName,
    String? sourceUrl,
    required String applyUrl,
    required String title,
    required String description,
    String? aiSummary,
    @JsonKey(unknownEnumValue: JobType.fullTime)
    @Default(JobType.fullTime)
    JobType jobType,
    String? category,
    @Default(<String>[]) List<String> requiredSkills,
    @Default(<String>[]) List<String> preferredSkills,
    String? minEdu,
    int? expMin,
    int? expMax,
    @JsonKey(unknownEnumValue: ExperienceLevel.midLevel)
    @Default(ExperienceLevel.midLevel)
    ExperienceLevel expLevel,
    @JsonKey(unknownEnumValue: EmploymentType.permanent)
    @Default(EmploymentType.permanent)
    EmploymentType employmentType,
    @JsonKey(unknownEnumValue: WorkMode.onsite)
    @Default(WorkMode.onsite)
    WorkMode workMode,
    @Default(<String>[]) List<String> locations,
    String? city,
    String? state,
    String? country,
    JobSalary? salary,
    @TimestampConverter() DateTime? deadline,
    @TimestampConverter() DateTime? postedAt,
    @JsonKey(unknownEnumValue: JobStatus.draftRaw)
    @Default(JobStatus.draftRaw)
    JobStatus status,
    @Default(JobVerification()) JobVerification verification,
    @Default(0) int reportCount,
    @TimestampConverter() DateTime? lastSeenAt,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

  factory Job.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return Job.fromJson({
      if (data != null) ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toFirestore() {
    final map = toJson();
    map.remove('id');
    return map;
  }

  // ── Backward-compatible convenience getters ────────────────────────────────
  bool get isVerified => verification.state == VerificationState.verified;
  String get location => locations.isNotEmpty ? locations.first : (city ?? '');
  int? get minSalary => salary?.min;
  int? get maxSalary => salary?.max;
  int? get minExperienceYears => expMin;
  int? get maxExperienceYears => expMax;
  DateTime? get closingDate => deadline;
  List<String> get skills => <String>[...requiredSkills, ...preferredSkills];
}

/// Backward-compatibility alias for JobModel
typedef JobModel = Job;
