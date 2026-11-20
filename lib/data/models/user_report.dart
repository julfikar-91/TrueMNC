// lib/data/models/user_report.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories supported by backend `submitReport`.
enum UserReportCategory {
  incorrectJob('INCORRECT_JOB', 'Incorrect Information'),
  brokenLink('BROKEN_LINK', 'Broken / Inactive Link'),
  suspiciousJob('SUSPICIOUS_JOB', 'Suspicious / Scam Job'),
  appIssue('APP_ISSUE', 'App Issue / Bug'),
  other('OTHER', 'Other');

  final String value;
  final String label;
  const UserReportCategory(this.value, this.label);

  static UserReportCategory fromString(String? val) {
    if (val == null) return UserReportCategory.other;
    return UserReportCategory.values.firstWhere(
      (c) => c.value == val.toUpperCase().trim(),
      orElse: () => UserReportCategory.other,
    );
  }
}

/// Status of report maintained by admins.
enum UserReportStatus {
  open('OPEN', 'Open'),
  inReview('IN_REVIEW', 'In Review'),
  resolved('RESOLVED', 'Resolved'),
  rejected('REJECTED', 'Rejected');

  final String value;
  final String label;
  const UserReportStatus(this.value, this.label);

  static UserReportStatus fromString(String? val) {
    if (val == null) return UserReportStatus.open;
    return UserReportStatus.values.firstWhere(
      (s) => s.value == val.toUpperCase().trim(),
      orElse: () => UserReportStatus.open,
    );
  }
}

/// User report model representing community feedback or flagged jobs.
class UserReport {
  const UserReport({
    required this.id,
    required this.reporterUid,
    required this.category,
    this.jobId,
    this.jobTitle,
    this.jobReportCount,
    required this.text,
    this.screenshotPath,
    required this.status,
    this.adminNote,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String reporterUid;
  final UserReportCategory category;
  final String? jobId;
  final String? jobTitle;
  final int? jobReportCount;
  final String text;
  final String? screenshotPath;
  final UserReportStatus status;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  factory UserReport.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserReport.fromMap(data, doc.id);
  }

  factory UserReport.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return UserReport(
      id: id ?? (data['id'] as String? ?? ''),
      reporterUid: data['reporterUid'] as String? ?? '',
      category: UserReportCategory.fromString(data['category'] as String?),
      jobId: data['jobId'] as String?,
      jobTitle: data['jobTitle'] as String?,
      jobReportCount: data['jobReportCount'] as int?,
      text: data['text'] as String? ?? '',
      screenshotPath: data['screenshotPath'] as String?,
      status: UserReportStatus.fromString(data['status'] as String?),
      adminNote: data['adminNote'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      resolvedAt: parseDate(data['resolvedAt']),
      resolvedBy: data['resolvedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporterUid': reporterUid,
      'category': category.value,
      if (jobId != null) 'jobId': jobId,
      if (jobTitle != null) 'jobTitle': jobTitle,
      'text': text,
      if (screenshotPath != null) 'screenshotPath': screenshotPath,
      'status': status.value,
      if (adminNote != null) 'adminNote': adminNote,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (resolvedAt != null) 'resolvedAt': resolvedAt,
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
    };
  }

  UserReport copyWith({
    String? id,
    String? reporterUid,
    UserReportCategory? category,
    String? jobId,
    String? jobTitle,
    int? jobReportCount,
    String? text,
    String? screenshotPath,
    UserReportStatus? status,
    String? adminNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return UserReport(
      id: id ?? this.id,
      reporterUid: reporterUid ?? this.reporterUid,
      category: category ?? this.category,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      jobReportCount: jobReportCount ?? this.jobReportCount,
      text: text ?? this.text,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      status: status ?? this.status,
      adminNote: adminNote ?? this.adminNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }
}
