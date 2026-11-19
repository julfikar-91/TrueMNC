// lib/data/models/company_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// Data source configuration for automated job collection from a company.
class CompanySource {
  const CompanySource({
    required this.id,
    required this.companyId,
    required this.type,
    required this.url,
    this.enabled = false,
    this.config = const {},
    this.secretRef,
    this.intervalMin = 360,
    this.nextRun,
    this.lastRun,
    this.consecutiveFailures = 0,
    this.needsAttention = false,
    this.verifiedAt,
    this.verifiedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String type; // GREENHOUSE, LEVER, SMARTRECRUITERS, OFFICIAL_FEED, CAREERS_PAGE
  final String url;
  final bool enabled;
  final Map<String, dynamic> config;
  final String? secretRef; // Secret Manager key identifier ONLY
  final int intervalMin;
  final DateTime? nextRun;
  final DateTime? lastRun;
  final int consecutiveFailures;
  final bool needsAttention;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isVerified => verifiedAt != null;

  SourceType get sourceType => SourceType.fromString(type);

  factory CompanySource.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data() ?? {};
    return CompanySource.fromJson({
      ...data,
      'id': doc.id,
    });
  }

  factory CompanySource.fromJson(Map<String, dynamic> json) {
    return CompanySource(
      id: json['id'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      type: (json['type'] as String? ?? 'CAREERS_PAGE').toUpperCase(),
      url: json['url'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      config: json['config'] != null
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
      secretRef: json['secretRef'] as String?,
      intervalMin: (json['intervalMin'] as num?)?.toInt() ?? 360,
      nextRun: _parseDate(json['nextRun']),
      lastRun: _parseDate(json['lastRun']),
      consecutiveFailures:
          (json['consecutiveFailures'] as num?)?.toInt() ?? 0,
      needsAttention: json['needsAttention'] as bool? ?? false,
      verifiedAt: _parseDate(json['verifiedAt']),
      verifiedBy: json['verifiedBy'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'type': type,
      'url': url,
      'enabled': enabled,
      'config': config,
      'secretRef': secretRef,
      'intervalMin': intervalMin,
      if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
      if (verifiedBy != null) 'verifiedBy': verifiedBy,
      'consecutiveFailures': consecutiveFailures,
      'needsAttention': needsAttention,
    };
  }

  CompanySource copyWith({
    String? id,
    String? companyId,
    String? type,
    String? url,
    bool? enabled,
    Map<String, dynamic>? config,
    String? secretRef,
    int? intervalMin,
    DateTime? nextRun,
    DateTime? lastRun,
    int? consecutiveFailures,
    bool? needsAttention,
    DateTime? verifiedAt,
    String? verifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanySource(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      type: type ?? this.type,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      config: config ?? this.config,
      secretRef: secretRef ?? this.secretRef,
      intervalMin: intervalMin ?? this.intervalMin,
      nextRun: nextRun ?? this.nextRun,
      lastRun: lastRun ?? this.lastRun,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      needsAttention: needsAttention ?? this.needsAttention,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
