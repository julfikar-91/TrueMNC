// lib/data/models/collection_run_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an execution record of an automated scraping/collection run.
class CollectionRunModel {
  const CollectionRunModel({
    required this.id,
    required this.sourceId,
    required this.companyId,
    required this.status, // RUNNING, COMPLETED, FAILED
    this.startedAt,
    this.completedAt,
    this.jobsFound = 0,
    this.jobsCreated = 0,
    this.jobsUpdated = 0,
    this.jobsClosed = 0,
    this.errors = const [],
    this.errorMessage,
  });

  final String id;
  final String sourceId;
  final String companyId;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int jobsFound;
  final int jobsCreated;
  final int jobsUpdated;
  final int jobsClosed;
  final List<String> errors;
  final String? errorMessage;

  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }

  bool get isSuccess => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';
  bool get isRunning => status == 'RUNNING';

  factory CollectionRunModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data() ?? {};
    return CollectionRunModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }

  factory CollectionRunModel.fromJson(Map<String, dynamic> json) {
    return CollectionRunModel(
      id: json['id'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      status: json['status'] as String? ?? 'RUNNING',
      startedAt: _parseDate(json['startedAt']),
      completedAt: _parseDate(json['completedAt']),
      jobsFound: (json['jobsFound'] as num?)?.toInt() ?? 0,
      jobsCreated: (json['jobsCreated'] as num?)?.toInt() ?? 0,
      jobsUpdated: (json['jobsUpdated'] as num?)?.toInt() ?? 0,
      jobsClosed: (json['jobsClosed'] as num?)?.toInt() ?? 0,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      errorMessage: json['errorMessage'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
