// lib/data/repositories/jobs_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/enums.dart';
import '../models/job.dart';
import '../services/firebase_service.dart';
import 'paged_controller.dart';

/// Primary jobs repository provider.
final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => JobsRepository(ref.watch(firestoreProvider)),
);

/// Backward-compatibility alias
final jobRepositoryProvider = jobsRepositoryProvider;

/// Repository handling all job queries and retrievals.
///
/// Follows non-negotiable rules:
/// - UI never calls Firestore directly.
/// - Always filters for `status == ACTIVE`.
/// - Supports cursor-based pagination (20 per page) via [PagedResult].
class JobsRepository {
  JobsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.jobsCollection);

  // ── 1. Paginated: Recently Added ───────────────────────────────────────────

  Future<PagedResult<Job>> recentlyAdded({
    int pageSize = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _col
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('postedAt', descending: true)
          .limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map(Job.fromFirestore).toList();
      final nextCursor = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PagedResult<Job>(
        items: items,
        nextCursor: nextCursor,
        hasMore: items.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 2. Paginated: By Job Type & Category ───────────────────────────────────

  Future<PagedResult<Job>> byTypeAndCategory({
    required JobType type,
    required String category,
    int pageSize = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final typeString = switch (type) {
        JobType.fullTime => 'FULL_TIME',
        JobType.partTime => 'PART_TIME',
        JobType.contract => 'CONTRACT',
        JobType.internship => 'INTERNSHIP',
        JobType.other => 'OTHER',
      };

      Query<Map<String, dynamic>> query = _col
          .where('status', isEqualTo: 'ACTIVE')
          .where('jobType', isEqualTo: typeString)
          .where('category', isEqualTo: category)
          .orderBy('postedAt', descending: true)
          .limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map(Job.fromFirestore).toList();
      final nextCursor = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PagedResult<Job>(
        items: items,
        nextCursor: nextCursor,
        hasMore: items.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 3. Paginated: By City ──────────────────────────────────────────────────

  Future<PagedResult<Job>> byCity({
    required String city,
    int pageSize = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _col
          .where('status', isEqualTo: 'ACTIVE')
          .where('city', isEqualTo: city)
          .orderBy('postedAt', descending: true)
          .limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map(Job.fromFirestore).toList();
      final nextCursor = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PagedResult<Job>(
        items: items,
        nextCursor: nextCursor,
        hasMore: items.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 4. Paginated: By Company ───────────────────────────────────────────────

  Future<PagedResult<Job>> byCompany({
    required String companyId,
    int pageSize = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _col
          .where('status', isEqualTo: 'ACTIVE')
          .where('companyId', isEqualTo: companyId)
          .orderBy('postedAt', descending: true)
          .limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map(Job.fromFirestore).toList();
      final nextCursor = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PagedResult<Job>(
        items: items,
        nextCursor: nextCursor,
        hasMore: items.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 5. Single Job by ID ────────────────────────────────────────────────────

  Future<Job?> getById(String jobId) async {
    try {
      final doc = await _col.doc(jobId).get();
      if (!doc.exists) return null;
      return Job.fromFirestore(doc);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Backward-compatibility alias
  Future<Job?> getJob(String jobId) => getById(jobId);

  // ── 6. Streams & Batch Fetching ────────────────────────────────────────────

  /// Real-time stream of latest active jobs.
  Stream<List<Job>> watchActiveJobs({int limit = AppConstants.defaultPageSize}) {
    try {
      return _col
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('postedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(Job.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Fetches a list of jobs by IDs (e.g. from server-side search results).
  Future<List<Job>> getJobsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final futures = ids.map((id) => _col.doc(id).get());
      final snaps = await Future.wait(futures);
      return snaps
          .where((d) => d.exists)
          .map(Job.fromFirestore)
          .toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Records an outbound application redirect after verifying the job is ACTIVE.
  ///
  /// Re-checks status in Firestore before returning the official application URL.
  Future<String> recordRedirect(String jobId) async {
    try {
      final doc = await _col.doc(jobId).get();
      if (!doc.exists) {
        throw const NotFoundException('This job posting was not found.');
      }
      final data = doc.data() ?? {};
      final status = data['status'] as String?;
      if (status != 'ACTIVE') {
        throw const ValidationException(
          'This position is no longer active and cannot accept new applications.',
        );
      }
      final applyUrl = data['applyUrl'] as String?;
      if (applyUrl == null || applyUrl.isEmpty) {
        throw const NotFoundException('Official application link is unavailable.');
      }
      return applyUrl;
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}
