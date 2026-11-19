// lib/data/models/app_notification.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'timestamp_converter.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

@freezed
class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    String? id,
    required String userId,
    required String title,
    required String body,
    @Default('JOB_MATCH') String type,
    Map<String, dynamic>? data,
    @Default(false) bool isRead,
    @TimestampConverter() DateTime? createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    return AppNotification.fromJson({
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
