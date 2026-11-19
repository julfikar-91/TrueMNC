// lib/data/models/profile_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'timestamp_converter.dart';

part 'profile_models.freezed.dart';
part 'profile_models.g.dart';

// ── 1. Education ─────────────────────────────────────────────────────────────

@freezed
class Education with _$Education {
  const Education._();

  const factory Education({
    String? id,
    String? institution,
    String? degree,
    String? fieldOfStudy,
    @TimestampConverter() DateTime? startDate,
    @TimestampConverter() DateTime? endDate,
    bool? current,
    String? grade,
    @JsonKey(unknownEnumValue: Provenance.explicit)
    @Default(Provenance.explicit)
    Provenance provenance,
  }) = _Education;

  factory Education.fromJson(Map<String, dynamic> json) =>
      _$EducationFromJson(json);

  factory Education.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return Education.fromJson({
      if (data != null) ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toFirestore() {
    final map = toJson();
    map.remove('id');
    return map;
  }
}

// ── 2. SkillItem ─────────────────────────────────────────────────────────────

@freezed
class SkillItem with _$SkillItem {
  const SkillItem._();

  const factory SkillItem({
    required String name,
    String? level,
    double? yearsOfExperience,
    @JsonKey(unknownEnumValue: Provenance.explicit)
    @Default(Provenance.explicit)
    Provenance provenance,
  }) = _SkillItem;

  factory SkillItem.fromJson(Map<String, dynamic> json) =>
      _$SkillItemFromJson(json);

  factory SkillItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return SkillItem.fromJson(data ?? {});
  }

  Map<String, dynamic> toFirestore() => toJson();
}

// ── 3. Experience ────────────────────────────────────────────────────────────

@freezed
class Experience with _$Experience {
  const Experience._();

  const factory Experience({
    String? id,
    required String company,
    required String title,
    String? location,
    @TimestampConverter() DateTime? startDate,
    @TimestampConverter() DateTime? endDate,
    bool? current,
    String? description,
    @Default(<String>[]) List<String> highlights,
    @JsonKey(unknownEnumValue: Provenance.explicit)
    @Default(Provenance.explicit)
    Provenance provenance,
  }) = _Experience;

  factory Experience.fromJson(Map<String, dynamic> json) =>
      _$ExperienceFromJson(json);

  factory Experience.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return Experience.fromJson({
      if (data != null) ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toFirestore() {
    final map = toJson();
    map.remove('id');
    return map;
  }
}

// ── 4. Project ───────────────────────────────────────────────────────────────

@freezed
class Project with _$Project {
  const Project._();

  const factory Project({
    String? id,
    required String title,
    String? description,
    String? url,
    @Default(<String>[]) List<String> skills,
    @TimestampConverter() DateTime? startDate,
    @TimestampConverter() DateTime? endDate,
    @JsonKey(unknownEnumValue: Provenance.explicit)
    @Default(Provenance.explicit)
    Provenance provenance,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);

  factory Project.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return Project.fromJson({
      if (data != null) ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toFirestore() {
    final map = toJson();
    map.remove('id');
    return map;
  }
}

// ── 5. Certification ─────────────────────────────────────────────────────────

@freezed
class Certification with _$Certification {
  const Certification._();

  const factory Certification({
    String? id,
    required String name,
    String? issuer,
    @TimestampConverter() DateTime? issueDate,
    @TimestampConverter() DateTime? expiryDate,
    String? credentialId,
    String? credentialUrl,
    @JsonKey(unknownEnumValue: Provenance.explicit)
    @Default(Provenance.explicit)
    Provenance provenance,
  }) = _Certification;

  factory Certification.fromJson(Map<String, dynamic> json) =>
      _$CertificationFromJson(json);

  factory Certification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return Certification.fromJson({
      if (data != null) ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toFirestore() {
    final map = toJson();
    map.remove('id');
    return map;
  }
}

// ── 6. CareerPreferences ─────────────────────────────────────────────────────

@freezed
class CareerPreferences with _$CareerPreferences {
  const CareerPreferences._();

  const factory CareerPreferences({
    @Default(<String>[]) List<String> desiredTitles,
    @Default(<String>[]) List<String> preferredLocations,
    @Default(<WorkMode>[]) List<WorkMode> preferredWorkModes,
    @Default(<JobType>[]) List<JobType> preferredJobTypes,
    @Default(<EmploymentType>[]) List<EmploymentType> preferredEmploymentTypes,
    int? minExpectedSalary,
    @Default('INR') String currency,
    int? noticePeriodDays,
    @JsonKey(unknownEnumValue: Provenance.explicit)
    @Default(Provenance.explicit)
    Provenance provenance,
  }) = _CareerPreferences;

  factory CareerPreferences.fromJson(Map<String, dynamic> json) =>
      _$CareerPreferencesFromJson(json);

  factory CareerPreferences.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return CareerPreferences.fromJson(data ?? {});
  }

  Map<String, dynamic> toFirestore() => toJson();
}
