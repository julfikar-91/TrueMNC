// lib/data/models/report_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'timestamp_converter.dart';

part 'report_item.freezed.dart';
part 'report_item.g.dart';

@freezed
class ReportItem with _$ReportItem {
  const ReportItem._();

  const factory ReportItem({
    String? id,
    required String jobId,
    required String userId,
    required String reason,
    String? details,
    @JsonKey(unknownEnumValue: ReportStatus.pending)
    @Default(ReportStatus.pending)
    ReportStatus status,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? reviewedAt,
    String? reviewedBy,
  }) = _ReportItem;

  factory ReportItem.fromJson(Map<String, dynamic> json) =>
      _$ReportItemFromJson(json);

  factory ReportItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return ReportItem.fromJson({
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
