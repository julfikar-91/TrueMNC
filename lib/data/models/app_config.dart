// lib/data/models/app_config.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_config.freezed.dart';
part 'app_config.g.dart';

// ── Score Labels ─────────────────────────────────────────────────────────────

@freezed
class ScoreLabels with _$ScoreLabels {
  const ScoreLabels._();

  const factory ScoreLabels({
    @Default(80) int excellent,
    @Default(65) int good,
    @Default(55) int fair,
  }) = _ScoreLabels;

  factory ScoreLabels.fromJson(Map<String, dynamic> json) =>
      _$ScoreLabelsFromJson(json);
}

// ── Scoring Config ───────────────────────────────────────────────────────────

@freezed
class ScoringConfig with _$ScoringConfig {
  const ScoringConfig._();

  const factory ScoringConfig({
    @Default(40) int skills,
    @Default(15) int education,
    @Default(15) int experience,
    @Default(10) int location,
    @Default(20) int preference,
    @Default(55) int threshold,
    @Default(74) int softCap,
    @Default(ScoreLabels()) ScoreLabels labels,
  }) = _ScoringConfig;

  factory ScoringConfig.fromJson(Map<String, dynamic> json) =>
      _$ScoringConfigFromJson(json);

  /// Validates that scoring weights sum to exactly 100%.
  int get totalWeight => skills + education + experience + location + preference;
  bool get isValid => totalWeight == 100;
}

// ── App Config ───────────────────────────────────────────────────────────────

@freezed
class AppConfig with _$AppConfig {
  const AppConfig._();

  const factory AppConfig({
    String? id,
    @Default(ScoringConfig()) ScoringConfig scoring,
    @Default('1.0.0') String minSupportedVersion,
    @Default(false) bool maintenanceMode,
    String? termsUrl,
    String? privacyUrl,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);

  factory AppConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return AppConfig.fromJson({
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
