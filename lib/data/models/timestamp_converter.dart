// lib/data/models/timestamp_converter.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Bidirectional converter between Firestore [Timestamp] and Dart [DateTime].
///
/// Accepts [Timestamp], [DateTime], ISO-8601 [String], epoch milliseconds [int],
/// or Firestore raw map representation ({'_seconds': ..., '_nanoseconds': ...}).
/// Serializes to [Timestamp] for Firestore compatibility and normalizes to UTC.
class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate().toUtc();
    if (json is DateTime) return json.toUtc();
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json, isUtc: true);
    if (json is String) return DateTime.tryParse(json)?.toUtc();
    if (json is Map) {
      final seconds = json['_seconds'] ?? json['seconds'];
      final nanoseconds = json['_nanoseconds'] ?? json['nanoseconds'] ?? 0;
      if (seconds is int) {
        final nanoMillis = (nanoseconds is int) ? nanoseconds ~/ 1000000 : 0;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + nanoMillis,
          isUtc: true,
        );
      }
    }
    return null;
  }

  @override
  Object? toJson(DateTime? object) {
    if (object == null) return null;
    return Timestamp.fromDate(object);
  }
}
