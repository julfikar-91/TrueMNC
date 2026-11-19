// lib/data/models/admin_job.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'job.dart';

/// Review claim holding 10-minute soft lock.
class ReviewClaim {
  const ReviewClaim({
    required this.claimedBy,
    required this.claimedAt,
  });

  final String claimedBy;
  final DateTime claimedAt;

  bool isLockedByOther(String currentUid) {
    if (claimedBy == currentUid) return false;
    final ageMs = DateTime.now().difference(claimedAt).inMilliseconds;
    return ageMs < 10 * 60 * 1000;
  }

  int get remainingSeconds {
    final ageMs = DateTime.now().difference(claimedAt).inMilliseconds;
    final leftMs = (10 * 60 * 1000) - ageMs;
    return leftMs > 0 ? (leftMs / 1000).ceil() : 0;
  }

  factory ReviewClaim.fromMap(Map<String, dynamic> map) {
    DateTime dt;
    final rawDate = map['claimedAt'];
    if (rawDate is Timestamp) {
      dt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      dt = rawDate;
    } else if (rawDate is String) {
      dt = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }

    return ReviewClaim(
      claimedBy: map['claimedBy'] as String? ?? '',
      claimedAt: dt,
    );
  }
}

/// Admin-enhanced view of a Job document with operational & review metadata.
class AdminJob {
  const AdminJob({
    required this.job,
    this.reviewReasons = const [],
    this.reviewClaim,
    this.companyLogo,
    this.sourceId,
    this.contentHash,
    this.rejectionReason,
    this.adminReviewNote,
    this.closedReason,
    this.canonicalJobId,
    this.missingCount = 0,
  });

  final Job job;
  final List<String> reviewReasons;
  final ReviewClaim? reviewClaim;
  final String? companyLogo;
  final String? sourceId;
  final String? contentHash;
  final String? rejectionReason;
  final String? adminReviewNote;
  final String? closedReason;
  final String? canonicalJobId;
  final int missingCount;

  String get id => job.id ?? '';
  String get title => job.title;
  String get companyName => job.companyName;
  String get companyId => job.companyId;
  String get applyUrl => job.applyUrl;
  String get description => job.description;
  String? get aiSummary => job.aiSummary;

  bool isLockedByOther(String currentUid) {
    return reviewClaim?.isLockedByOther(currentUid) ?? false;
  }

  factory AdminJob.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data() ?? {};
    final job = Job.fromFirestore(doc, options);

    final rawClaim = data['reviewClaim'];
    ReviewClaim? claim;
    if (rawClaim is Map<String, dynamic>) {
      claim = ReviewClaim.fromMap(rawClaim);
    }

    final reasons = (data['reviewReasons'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    return AdminJob(
      job: job,
      reviewReasons: reasons,
      reviewClaim: claim,
      companyLogo: data['companyLogo'] as String?,
      sourceId: data['sourceId'] as String?,
      contentHash: data['contentHash'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      adminReviewNote: data['adminReviewNote'] as String?,
      closedReason: data['closedReason'] as String?,
      canonicalJobId: data['canonicalJobId'] as String?,
      missingCount: (data['missingCount'] as num?)?.toInt() ?? 0,
    );
  }
}
