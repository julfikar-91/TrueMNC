// lib/data/repositories/admin_report_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo/demo_provider.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/user_report.dart';
import '../services/firebase_service.dart';
import 'paged_controller.dart';

/// Provider for [AdminReportRepository].
final adminReportRepositoryProvider = Provider<AdminReportRepository>((ref) {
  final isDemo = ref.watch(isDemoModeProvider);
  if (isDemo) {
    return MockAdminReportRepository();
  }
  return AdminReportRepository(
    ref.watch(cloudFunctionsProvider),
    ref.watch(firestoreProvider),
  );
});

class AdminReportRepository {
  AdminReportRepository([this._functions, this._firestore]);

  final FirebaseFunctions? _functions;
  final FirebaseFirestore? _firestore;

  /// Fetches paginated reports with optional status filter.
  Future<PagedResult<UserReport>> getPagedReports({
    UserReportStatus? status,
    int pageSize = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      if (_firestore == null) {
        return const PagedResult(items: [], hasMore: false);
      }

      Query<Map<String, dynamic>> query = _firestore!.collection('reports');

      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      query = query.orderBy('createdAt', descending: true).limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final reports = <UserReport>[];

      for (final doc in snapshot.docs) {
        final report = UserReport.fromFirestore(doc);
        reports.add(report);
      }

      final nextCursor = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PagedResult(
        items: reports,
        nextCursor: nextCursor,
        hasMore: reports.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Updates report status and sends optional admin reply note.
  Future<void> updateReportStatus({
    required String reportId,
    required UserReportStatus status,
    String? adminNote,
  }) async {
    try {
      if (_functions == null) throw Exception('Firebase Functions unavailable');

      final callable = _functions!.httpsCallable('adminUpdateReport');
      await callable.call<Map<String, dynamic>>({
        'reportId': reportId,
        'status': status.value,
        if (adminNote != null && adminNote.trim().isNotEmpty)
          'adminNote': adminNote.trim(),
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}

class MockAdminReportRepository extends AdminReportRepository {
  MockAdminReportRepository() : super();

  final List<UserReport> _mockAdminReports = [
    UserReport(
      id: 'rep_101',
      reporterUid: 'user_cand_992',
      category: UserReportCategory.suspiciousJob,
      jobId: 'job_001',
      jobTitle: 'Senior Cloud Architect',
      jobReportCount: 3,
      text: 'Requires payment for initial interview registration fee! Seems suspicious.',
      status: UserReportStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    UserReport(
      id: 'rep_102',
      reporterUid: 'user_cand_431',
      category: UserReportCategory.brokenLink,
      jobId: 'job_002',
      jobTitle: 'Frontend Engineer (React)',
      jobReportCount: 1,
      text: 'Career link redirects to 404 page.',
      status: UserReportStatus.inReview,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    UserReport(
      id: 'rep_103',
      reporterUid: 'user_cand_112',
      category: UserReportCategory.incorrectJob,
      jobId: 'job_003',
      jobTitle: 'Staff Backend Architect',
      jobReportCount: 4,
      text: 'Job description does not match actual team role in Hyderabad.',
      status: UserReportStatus.resolved,
      adminNote: 'Corrected job department and requirements based on careers API sync.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      resolvedAt: DateTime.now().subtract(const Duration(hours: 10)),
      resolvedBy: 'admin_master',
    ),
  ];

  @override
  Future<PagedResult<UserReport>> getPagedReports({
    UserReportStatus? status,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var list = _mockAdminReports;
    if (status != null) {
      list = list.where((r) => r.status == status).toList();
    }

    return PagedResult(
      items: list.take(pageSize).toList(),
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required UserReportStatus status,
    String? adminNote,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _mockAdminReports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _mockAdminReports[idx] = _mockAdminReports[idx].copyWith(
        status: status,
        adminNote: adminNote,
        resolvedAt: (status == UserReportStatus.resolved || status == UserReportStatus.rejected)
            ? DateTime.now()
            : null,
      );
    }
  }
}
