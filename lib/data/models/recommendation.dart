// lib/data/models/recommendation.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'timestamp_converter.dart';

part 'recommendation.freezed.dart';
part 'recommendation.g.dart';

// ── Score Breakdown ──────────────────────────────────────────────────────────

@freezed
class ScoreBreakdown with _$ScoreBreakdown {
  const ScoreBreakdown._();

  const factory ScoreBreakdown({
    @Default(0.0) double skills,
    @Default(0.0) double education,
    @Default(0.0) double experience,
    @Default(0.0) double location,
    @Default(0.0) double preference,
  }) = _ScoreBreakdown;

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) =>
      _$ScoreBreakdownFromJson(json);
}

// ── Recommendation ───────────────────────────────────────────────────────────

@freezed
class Recommendation with _$Recommendation {
  const Recommendation._();

  const factory Recommendation({
    String? id,
    String? jobId,
    String? userId,
    required double score,
    @Default(ScoreBreakdown()) ScoreBreakdown breakdown,
    @Default(<String>[]) List<String> matchedSkills,
    @Default(<String>[]) List<String> missingSkills,
    @Default(<String>[]) List<String> reasons,
    @Default('v1') String scoreVersion,
    @Default(true) bool isNew,
    @TimestampConverter() DateTime? computedAt,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);

  factory Recommendation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return Recommendation.fromJson({
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
