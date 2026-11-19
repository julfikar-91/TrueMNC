// lib/data/models/company.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'timestamp_converter.dart';

part 'company.freezed.dart';
part 'company.g.dart';

// ── Source ───────────────────────────────────────────────────────────────────

@freezed
class Source with _$Source {
  const Source._();

  const factory Source({
    String? id,
    String? companyId,
    @JsonKey(unknownEnumValue: SourceType.careersPage)
    @Default(SourceType.careersPage)
    SourceType type,
    required String url,
    @Default(true) bool isActive,
    @TimestampConverter() DateTime? lastSyncAt,
    @TimestampConverter() DateTime? createdAt,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);

  factory Source.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return Source.fromJson({
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

// ── Company ──────────────────────────────────────────────────────────────────

@freezed
class Company with _$Company {
  const Company._();

  const factory Company({
    String? id,
    required String name,
    String? slug,
    String? website,
    String? careersUrl,
    String? logoUrl,
    String? description,
    String? industry,
    String? headquarters,
    @Default(false) bool isVerified,
    @Default(<Source>[]) List<Source> sources,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _Company;

  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);

  factory Company.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return Company.fromJson({
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

// ── CollectionRun ────────────────────────────────────────────────────────────

@freezed
class CollectionRun with _$CollectionRun {
  const CollectionRun._();

  const factory CollectionRun({
    String? id,
    String? sourceId,
    String? companyId,
    @Default('RUNNING') String status,
    @Default(0) int jobsFound,
    @Default(0) int jobsCreated,
    @Default(0) int jobsUpdated,
    @Default(<String>[]) List<String> errors,
    @TimestampConverter() DateTime? startedAt,
    @TimestampConverter() DateTime? completedAt,
  }) = _CollectionRun;

  factory CollectionRun.fromJson(Map<String, dynamic> json) =>
      _$CollectionRunFromJson(json);

  factory CollectionRun.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return CollectionRun.fromJson({
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

/// Backward-compatibility alias for CompanyModel
typedef CompanyModel = Company;
