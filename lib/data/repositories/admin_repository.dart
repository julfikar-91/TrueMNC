// lib/data/repositories/admin_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo/demo_provider.dart';
import '../../core/demo/mock_repositories.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_handler.dart';
import '../models/admin_job.dart';
import '../models/app_user.dart';
import '../models/audit_log.dart';
import '../models/collection_run_model.dart';
import '../models/company.dart';
import '../models/company_source.dart';
import '../models/job_validation_model.dart';
import '../services/firebase_service.dart';
import 'paged_controller.dart';

/// Provider for [AdminRepository].
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final isDemo = ref.watch(isDemoModeProvider);
  if (isDemo) {
    return MockAdminRepository();
  }
  return AdminRepository(
    ref.watch(cloudFunctionsProvider),
    ref.watch(firestoreProvider),
  );
});

/// The ONLY class authorized to invoke admin Cloud Function callables
/// and stream audit / operational telemetry.
///
/// Follows non-negotiable security rules:
/// - Client can never set roles or change scoring config directly in Firestore.
/// - All privileged actions execute server-side via trusted Gen 2 Cloud Functions.
class AdminRepository {
  AdminRepository(this._functions, this._firestore);

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  // ── 1. Admin Callables (Server-side Execution) ─────────────────────────────

  /// Invokes `upsertCompany` Cloud Function to create or update verified company profiles.
  Future<Map<String, dynamic>> upsertCompany(
      Map<String, dynamic> companyData) async {
    try {
      final callable = _functions.httpsCallable('upsertCompany');
      final result = await callable.call<Map<String, dynamic>>(companyData);
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Invokes `setUserRole` Cloud Function (SUPER_ADMIN only).
  /// Sets custom claims in Firebase Auth. Roles never exist as Firestore fields.
  Future<void> setUserRole({
    String? uid,
    String? email,
    required String role,
  }) async {
    try {
      final callable = _functions.httpsCallable('setUserRole');
      await callable.call<dynamic>({
        if (uid != null) 'targetUid': uid,
        if (email != null) 'targetEmail': email,
        'role': role,
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Invokes `updateScoringConfig` Cloud Function to update app-wide weights & thresholds.
  Future<void> updateScoringConfig(Map<String, dynamic> config) async {
    try {
      final callable = _functions.httpsCallable('updateScoringConfig');
      await callable.call<dynamic>(config);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Invokes `updateAppConfig` Cloud Function to update app-wide system configuration.
  Future<void> updateAppConfig(Map<String, dynamic> config) async {
    try {
      final callable = _functions.httpsCallable('updateAppConfig');
      await callable.call<dynamic>(config);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── Source Actions Callables ───────────────────────────────────────────────

  /// Creates or updates a company data source.
  Future<Map<String, dynamic>> adminUpsertSource(
      Map<String, dynamic> sourceData) async {
    try {
      final callable = _functions.httpsCallable('adminUpsertSource');
      final result = await callable.call<Map<String, dynamic>>(sourceData);
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Dry-run tests an adapter connection and runs R1-R8 on up to 3 samples.
  Future<Map<String, dynamic>> adminTestSource(
      Map<String, dynamic> testPayload) async {
    try {
      final callable = _functions.httpsCallable('adminTestSource');
      final result = await callable.call<Map<String, dynamic>>(testPayload);
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Signs off and verifies a company source, enabling automated collection.
  Future<Map<String, dynamic>> adminVerifySource({
    required String sourceId,
    required String companyId,
    required bool adminSignOff,
    bool enableCollection = true,
  }) async {
    try {
      final callable = _functions.httpsCallable('adminVerifySource');
      final result = await callable.call<Map<String, dynamic>>({
        'sourceId': sourceId,
        'companyId': companyId,
        'adminSignOff': adminSignOff,
        'enableCollection': enableCollection,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Manually triggers a collection run immediately (rate-limited).
  Future<Map<String, dynamic>> adminRunCollectionNow(String sourceId) async {
    try {
      final callable = _functions.httpsCallable('adminRunCollectionNow');
      final result = await callable.call<Map<String, dynamic>>({
        'sourceId': sourceId,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── Job Review Callables ───────────────────────────────────────────────────

  /// Approves a job and transitions it to ACTIVE + VERIFIED.
  Future<void> adminApproveJob(String jobId, [String? note]) async {
    try {
      final callable = _functions.httpsCallable('adminApproveJob');
      await callable.call<dynamic>({
        'jobId': jobId,
        if (note != null && note.isNotEmpty) 'note': note,
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Rejects a job (rejection reason is strictly required).
  Future<void> adminRejectJob(String jobId, String reason) async {
    if (reason.trim().length < 3) {
      throw const ValidationException('Rejection reason must be at least 3 characters.');
    }
    try {
      final callable = _functions.httpsCallable('adminRejectJob');
      await callable.call<dynamic>({
        'jobId': jobId,
        'reason': reason.trim(),
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Requests changes on a job with an administrator review note.
  Future<void> adminRequestChanges(String jobId, String adminNote) async {
    if (adminNote.trim().length < 3) {
      throw const ValidationException('Admin note must be at least 3 characters.');
    }
    try {
      final callable = _functions.httpsCallable('adminRequestChanges');
      await callable.call<dynamic>({
        'jobId': jobId,
        'adminNote': adminNote.trim(),
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Closes an active job manually.
  Future<void> adminCloseJob(String jobId, [String? reason]) async {
    try {
      final callable = _functions.httpsCallable('adminCloseJob');
      await callable.call<dynamic>({
        'jobId': jobId,
        if (reason != null) 'reason': reason,
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Marks a job as duplicate with an optional canonical job reference.
  Future<void> adminMarkDuplicate(String jobId, [String? canonicalJobId]) async {
    try {
      final callable = _functions.httpsCallable('adminMarkDuplicate');
      await callable.call<dynamic>({
        'jobId': jobId,
        if (canonicalJobId != null) 'canonicalJobId': canonicalJobId,
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Re-evaluates verification rules R1-R8 for an existing job.
  Future<Map<String, dynamic>> adminReverifyJob(String jobId) async {
    try {
      final callable = _functions.httpsCallable('adminReverifyJob');
      final result = await callable.call<Map<String, dynamic>>({
        'jobId': jobId,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Re-runs Gemini AI schema extraction on job description.
  Future<Map<String, dynamic>> adminRerunExtraction(String jobId) async {
    try {
      final callable = _functions.httpsCallable('adminRerunExtraction');
      final result = await callable.call<Map<String, dynamic>>({
        'jobId': jobId,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Executes bulk close or reject on up to 50 jobs (reason strictly required).
  Future<void> adminBulkAction({
    required String action, // CLOSE | REJECT
    required List<String> jobIds,
    required String reason,
  }) async {
    if (reason.trim().length < 3) {
      throw const ValidationException('Bulk action reason must be at least 3 characters.');
    }
    if (jobIds.isEmpty) {
      throw const ValidationException('No jobs selected.');
    }
    try {
      final callable = _functions.httpsCallable('adminBulkAction');
      await callable.call<dynamic>({
        'action': action,
        'jobIds': jobIds,
        'reason': reason.trim(),
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Claims a job for review with a 10-minute soft lock.
  Future<Map<String, dynamic>> claimReviewItem(String jobId) async {
    try {
      final callable = _functions.httpsCallable('claimReviewItem');
      final result = await callable.call<Map<String, dynamic>>({
        'jobId': jobId,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 2. Streams & Real-Time Collections ────────────────────────────────────

  /// Streams list of administrators (users with role ADMIN or SUPER_ADMIN).
  Stream<List<AppUser>> watchAdministrators() {
    try {
      return _firestore
          .collection('users')
          .where('role', whereIn: ['ADMIN', 'SUPER_ADMIN'])
          .snapshots()
          .map((snap) => snap.docs.map(AppUser.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams audit logs in real time. Permitted only for users with ADMIN or SUPER_ADMIN claim.
  Stream<List<AuditLog>> watchAuditLogs({int limit = 50}) {
    try {
      return _firestore
          .collection('auditLogs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(AuditLog.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Fetches audit logs once.
  Future<List<AuditLog>> getAuditLogs({int limit = 50}) async {
    try {
      final snap = await _firestore
          .collection('auditLogs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(AuditLog.fromFirestore).toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Paginated list of audit logs supporting filtering.
  Future<PagedResult<AuditLog>> listAuditLogs({
    int pageSize = 20,
    DocumentSnapshot? startAfter,
    String? actor,
    String? action,
    String? target,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('auditLogs');

      if (action != null && action.isNotEmpty && action != 'ALL') {
        query = query.where('action', isEqualTo: action);
      }
      if (actor != null && actor.trim().isNotEmpty) {
        query = query.where('performedBy', isEqualTo: actor.trim());
      }
      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('timestamp', descending: true);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(pageSize);

      final snap = await query.get();
      var items = snap.docs.map(AuditLog.fromFirestore).toList();

      if (target != null && target.trim().isNotEmpty) {
        final t = target.trim().toLowerCase();
        items = items.where((log) {
          final tId = log.targetId.toLowerCase();
          final tType = log.targetType.toLowerCase();
          final tPath =
              (log.details?['targetPath']?.toString() ?? '').toLowerCase();
          return tId.contains(t) || tType.contains(t) || tPath.contains(t);
        }).toList();
      }

      final nextCursor = snap.docs.isNotEmpty ? snap.docs.last : null;
      return PagedResult<AuditLog>(
        items: items,
        nextCursor: nextCursor,
        hasMore: snap.docs.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams operational stats from `/stats/global` or `/stats/overview`.
  Stream<Map<String, dynamic>> watchStats() {
    try {
      return _firestore
          .collection('stats')
          .doc('global')
          .snapshots()
          .map((snap) => snap.data() ?? <String, dynamic>{});
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams current scoring configuration.
  Stream<Map<String, dynamic>> watchScoringConfig() {
    try {
      return _firestore
          .collection('config')
          .doc('scoring_v1')
          .snapshots()
          .map((snap) => snap.data() ?? <String, dynamic>{});
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams current app configuration.
  Stream<Map<String, dynamic>> watchAppConfig() {
    try {
      return _firestore
          .collection('config')
          .doc('app')
          .snapshots()
          .map((snap) => snap.data() ?? <String, dynamic>{});
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Fetches historical version snapshots for a config document.
  Future<List<Map<String, dynamic>>> getConfigVersions(String configDoc) async {
    try {
      final snap = await _firestore
          .collection('config')
          .doc(configDoc)
          .collection('versions')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      return snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 3. Sources & Collection Runs Streams ───────────────────────────────────

  /// Streams all sources configured for a specific company.
  Stream<List<CompanySource>> watchCompanySources(String companyId) {
    try {
      return _firestore
          .collection('sources')
          .where('companyId', isEqualTo: companyId)
          .snapshots()
          .map((snap) => snap.docs.map(CompanySource.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams a single source document.
  Stream<CompanySource?> watchSource(String sourceId) {
    try {
      return _firestore
          .collection('sources')
          .doc(sourceId)
          .snapshots()
          .map((snap) => snap.exists ? CompanySource.fromFirestore(snap) : null);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams collection runs (optionally filtered by companyId or sourceId).
  Stream<List<CollectionRunModel>> watchCollectionRuns({
    String? companyId,
    String? sourceId,
    int limit = 20,
  }) {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('collectionRuns');
      if (companyId != null && companyId.isNotEmpty) {
        query = query.where('companyId', isEqualTo: companyId);
      }
      if (sourceId != null && sourceId.isNotEmpty) {
        query = query.where('sourceId', isEqualTo: sourceId);
      }
      query = query.orderBy('startedAt', descending: true).limit(limit);

      return query.snapshots().map(
            (snap) => snap.docs.map(CollectionRunModel.fromFirestore).toList(),
          );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 4. Jobs & Review Queue Queries ─────────────────────────────────────────

  /// Streams review queue jobs (status == PENDING_REVIEW).
  Stream<List<AdminJob>> watchReviewQueue({int limit = 50}) {
    try {
      return _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'PENDING_REVIEW')
          .orderBy('postedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(AdminJob.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams validation records for a job from `jobs/{jobId}/validations`.
  Stream<List<JobValidationModel>> watchJobValidations(String jobId) {
    try {
      return _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('validations')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .map((snap) => snap.docs.map(JobValidationModel.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Fetches a single job with admin details.
  Future<AdminJob?> getAdminJob(String jobId) async {
    try {
      final doc = await _firestore.collection('jobs').doc(jobId).get();
      if (!doc.exists) return null;
      return AdminJob.fromFirestore(doc);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams a single job with admin details.
  Stream<AdminJob?> watchAdminJob(String jobId) {
    try {
      return _firestore
          .collection('jobs')
          .doc(jobId)
          .snapshots()
          .map((doc) => doc.exists ? AdminJob.fromFirestore(doc) : null);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Paginated list of jobs for Admin with multi-field filtering.
  Future<PagedResult<AdminJob>> listAdminJobs({
    int pageSize = 20,
    DocumentSnapshot? startAfter,
    String? companyId,
    String? category,
    String? verificationState,
    String? status,
    String? sourcePlatform,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('jobs');

      if (status != null && status.isNotEmpty && status != 'ALL') {
        query = query.where('status', isEqualTo: status);
      }
      if (companyId != null && companyId.isNotEmpty && companyId != 'ALL') {
        query = query.where('companyId', isEqualTo: companyId);
      }
      if (category != null && category.isNotEmpty && category != 'ALL') {
        query = query.where('category', isEqualTo: category);
      }
      if (verificationState != null &&
          verificationState.isNotEmpty &&
          verificationState != 'ALL') {
        query = query.where('verification.state', isEqualTo: verificationState);
      }
      if (startDate != null) {
        query = query.where('postedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('postedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('postedAt', descending: true);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(pageSize);

      final snap = await query.get();
      var items = snap.docs.map(AdminJob.fromFirestore).toList();

      // Client-side filtering for search query if provided
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        items = items.where((j) {
          final title = j.title.toLowerCase();
          final comp = j.companyName.toLowerCase();
          final cat = (j.job.category ?? '').toLowerCase();
          return title.contains(q) || comp.contains(q) || cat.contains(q);
        }).toList();
      }

      final nextCursor = snap.docs.isNotEmpty ? snap.docs.last : null;
      return PagedResult<AdminJob>(
        items: items,
        nextCursor: nextCursor,
        hasMore: snap.docs.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}
