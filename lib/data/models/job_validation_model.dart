// lib/data/models/job_validation_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Single rule evaluation result within a job validation snapshot.
class RuleResultItem {
  const RuleResultItem({
    required this.ruleCode,
    required this.result, // PASS, FAIL
    this.details,
  });

  final String ruleCode;
  final String result;
  final String? details;

  bool get isPass => result == 'PASS';

  factory RuleResultItem.fromJson(Map<String, dynamic> json) {
    return RuleResultItem(
      ruleCode: json['ruleCode'] as String? ?? '',
      result: json['result'] as String? ?? 'FAIL',
      details: json['details'] as String?,
    );
  }
}

/// Validation record written to `jobs/{jobId}/validations/{valId}`.
class JobValidationModel {
  const JobValidationModel({
    required this.id,
    this.collectionRunId,
    this.timestamp,
    this.allPass = false,
    this.results = const [],
    this.reasonCodes = const [],
  });

  final String id;
  final String? collectionRunId;
  final DateTime? timestamp;
  final bool allPass;
  final List<RuleResultItem> results;
  final List<String> reasonCodes;

  factory JobValidationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data() ?? {};
    return JobValidationModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }

  factory JobValidationModel.fromJson(Map<String, dynamic> json) {
    return JobValidationModel(
      id: json['id'] as String? ?? '',
      collectionRunId: json['collectionRunId'] as String?,
      timestamp: _parseDate(json['timestamp']),
      allPass: json['allPass'] as bool? ?? false,
      results: (json['results'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(RuleResultItem.fromJson)
              .toList() ??
          const [],
      reasonCodes: (json['reasonCodes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
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
