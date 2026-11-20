// lib/data/repositories/report_repository.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo/demo_provider.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/user_report.dart';
import '../services/firebase_service.dart';

/// Provider for [ReportRepository].
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final isDemo = ref.watch(isDemoModeProvider);
  if (isDemo) {
    return MockReportRepository();
  }
  return ReportRepository(
    ref.watch(cloudFunctionsProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  );
});

class ReportRepository {
  ReportRepository([this._functions, this._firestore, this._storage]);

  final FirebaseFunctions? _functions;
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  /// Submits a user report via Gen 2 Cloud Function `submitReport`.
  Future<String> submitReport({
    required UserReportCategory category,
    String? jobId,
    required String text,
    String? screenshotPath,
  }) async {
    try {
      if (_functions == null) throw Exception('Firebase Functions unavailable');

      final callable = _functions!.httpsCallable('submitReport');
      final res = await callable.call<Map<String, dynamic>>({
        'category': category.value,
        if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
        'text': text.trim(),
        if (screenshotPath != null && screenshotPath.isNotEmpty)
          'screenshotPath': screenshotPath,
      });

      final data = Map<String, dynamic>.from(res.data);
      return data['reportId'] as String? ?? 'ok';
    } catch (e, st) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('resource-exhausted') || msg.contains('limit reached')) {
        throw Exception('Daily report limit reached (max 10 reports per day).');
      }
      throw handleException(e, st);
    }
  }

  /// Streams user's submitted reports.
  Stream<List<UserReport>> watchMyReports(String uid) {
    if (_firestore == null) return Stream.value([]);
    try {
      return _firestore!
          .collection('reports')
          .where('reporterUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(UserReport.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Uploads screenshot to storage under `reports/{uid}/...` (strictly enforced by backend & rules).
  Future<String> uploadScreenshot(
    String uid,
    Uint8List bytes,
    String extension,
  ) async {
    if (_storage == null) throw Exception('Firebase Storage unavailable');
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = 'reports/$uid/$filename';
    final ref = _storage!.ref().child(path);

    final metadata = SettableMetadata(
      contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
    );
    await ref.putData(bytes, metadata);
    return path;
  }
}

class MockReportRepository extends ReportRepository {
  MockReportRepository() : super();

  final List<UserReport> _mockReports = [
    UserReport(
      id: 'rep_001',
      reporterUid: 'mock_candidate_001',
      category: UserReportCategory.incorrectJob,
      jobId: 'job_001',
      jobTitle: 'Senior Cloud Architect',
      jobReportCount: 3,
      text: 'The salary range mentioned is completely outdated compared to the careers page.',
      status: UserReportStatus.resolved,
      adminNote: 'Thank you for reporting. The salary information has been updated from the official feed.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      resolvedAt: DateTime.now().subtract(const Duration(days: 1)),
      resolvedBy: 'admin_001',
    ),
    UserReport(
      id: 'rep_002',
      reporterUid: 'mock_candidate_001',
      category: UserReportCategory.brokenLink,
      jobId: 'job_002',
      jobTitle: 'Frontend Engineer (React)',
      jobReportCount: 1,
      text: 'Clicking Apply gives a 404 error on the corporate careers portal.',
      status: UserReportStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  int _todayCount = 0;

  @override
  Future<String> submitReport({
    required UserReportCategory category,
    String? jobId,
    required String text,
    String? screenshotPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_todayCount >= 10) {
      throw Exception('Daily report limit reached (max 10 reports per day).');
    }
    _todayCount++;

    final newReport = UserReport(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      reporterUid: 'mock_candidate_001',
      category: category,
      jobId: jobId,
      jobTitle: jobId != null ? 'Sample Job Title' : null,
      jobReportCount: 1,
      text: text,
      screenshotPath: screenshotPath,
      status: UserReportStatus.open,
      createdAt: DateTime.now(),
    );
    _mockReports.insert(0, newReport);
    return newReport.id;
  }

  @override
  Stream<List<UserReport>> watchMyReports(String uid) {
    return Stream.value(_mockReports);
  }

  @override
  Future<String> uploadScreenshot(
    String uid,
    Uint8List bytes,
    String extension,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return 'reports/$uid/mock_${DateTime.now().millisecondsSinceEpoch}.$extension';
  }
}
