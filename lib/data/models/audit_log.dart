// lib/data/models/audit_log.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'timestamp_converter.dart';

part 'audit_log.freezed.dart';
part 'audit_log.g.dart';

@freezed
class AuditLog with _$AuditLog {
  const AuditLog._();

  const factory AuditLog({
    String? id,
    required String action,
    required String performedBy,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? details,
    String? ipAddress,
    String? userAgent,
    @TimestampConverter() DateTime? timestamp,
  }) = _AuditLog;

  factory AuditLog.fromJson(Map<String, dynamic> json) =>
      _$AuditLogFromJson(json);

  factory AuditLog.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data() ?? {};
    final targetPath = data['targetPath']?.toString() ?? '';
    final pathParts = targetPath.split('/');
    final details = <String, dynamic>{
      if (data['details'] is Map<String, dynamic>) ...(data['details'] as Map<String, dynamic>),
      if (data['metadata'] is Map<String, dynamic>) ...(data['metadata'] as Map<String, dynamic>),
      if (data['before'] != null) 'before': data['before'],
      if (data['after'] != null) 'after': data['after'],
      if (data['role'] != null) 'role': data['role'],
      if (data['ipHash'] != null) 'ipHash': data['ipHash'],
      if (targetPath.isNotEmpty) 'targetPath': targetPath,
    };
    return AuditLog.fromJson({
      'id': doc.id,
      'action': data['action'] ?? '',
      'performedBy': data['performedBy'] ?? data['actorUid'] ?? 'System',
      'targetType': data['targetType'] ?? (pathParts.isNotEmpty ? pathParts.first : 'UNKNOWN'),
      'targetId': data['targetId'] ?? (pathParts.length > 1 ? pathParts.sublist(1).join('/') : targetPath),
      'details': details.isNotEmpty ? details : null,
      'ipAddress': data['ipAddress'] ?? data['ipHash'],
      'userAgent': data['userAgent'],
      'timestamp': data['timestamp'] ?? data['at'],
    });
  }

  Map<String, dynamic> toFirestore() {
    final map = toJson();
    map.remove('id');
    return map;
  }
}

extension AuditLogDetailsX on AuditLog {
  dynamic get before => details?['before'];
  dynamic get after => details?['after'];
  String? get targetPath => details?['targetPath'] as String?;
}
