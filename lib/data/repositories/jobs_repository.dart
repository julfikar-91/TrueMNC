// lib/data/repositories/jobs_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo/demo_provider.dart';
import '../../core/demo/mock_repositories.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/enums.dart';
import '../models/job.dart';
import '../models/job_query.dart';
import '../services/firebase_service.dart';
import 'paged_controller.dart';

/// Primary jobs repository provider.
final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  final isDemo = ref.watch(isDemoModeProvider);
  if (isDemo) {
    return MockJobsRepository();
  }
  return JobsRepository(ref.watch(firestoreProvider));
});

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

  // ── 4b. Filtered Search Query ──────────────────────────────────────────────

  Future<PagedResult<Job>> queryJobs(
    JobQuery query, {
    int pageSize = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> firestoreQuery =
          _col.where('status', isEqualTo: 'ACTIVE');

      if (query.category != null && query.category!.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('category', isEqualTo: query.category);
      }
      if (query.city != null && query.city!.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('city', isEqualTo: query.city);
      }
      if (query.jobType != null && query.jobType!.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('jobType', isEqualTo: query.jobType);
      }

      firestoreQuery = firestoreQuery
          .orderBy('postedAt', descending: true)
          .limit(pageSize * 2);

      if (startAfter != null) {
        firestoreQuery = firestoreQuery.startAfterDocument(startAfter);
      }

      final snapshot = await firestoreQuery.get();
      var items = snapshot.docs.map(Job.fromFirestore).toList();

      items = items
          .where(
            (j) =>
                j.status == JobStatus.active &&
                j.verification.state == VerificationState.verified &&
                j.applyUrl.isNotEmpty,
          )
          .toList();

      if (query.skills.isNotEmpty) {
        final querySkillsLower =
            query.skills.map((s) => s.toLowerCase()).toSet();
        items = items.where((j) {
          final jobSkills = [
            ...j.requiredSkills.map((s) => s.toLowerCase()),
            ...j.preferredSkills.map((s) => s.toLowerCase()),
          ];
          return jobSkills.any(
            (s) =>
                querySkillsLower.contains(s) ||
                querySkillsLower.any((qs) => s.contains(qs)),
          );
        }).toList();
      }

      if (query.titles.isNotEmpty) {
        final titlesLower = query.titles.map((t) => t.toLowerCase()).toList();
        items = items.where((j) {
          final t = j.title.toLowerCase();
          return titlesLower.any((qt) => t.contains(qt));
        }).toList();
      }

      if (query.workMode != null && query.workMode!.isNotEmpty) {
        final wm = query.workMode!.toLowerCase();
        items = items
            .where((j) => j.workMode.name.toLowerCase().contains(wm))
            .toList();
      }

      if (query.experienceLevel != null && query.experienceLevel!.isNotEmpty) {
        final exp = query.experienceLevel!.toLowerCase();
        if (exp.contains('fresh') || exp.contains('0')) {
          items = items.where((j) => (j.expMin ?? 0) == 0).toList();
        }
      }

      if (query.keyword != null && query.keyword!.trim().isNotEmpty) {
        final kw = query.keyword!.trim().toLowerCase();
        items = items
            .where(
              (j) =>
                  j.title.toLowerCase().contains(kw) ||
                  j.companyName.toLowerCase().contains(kw) ||
                  j.description.toLowerCase().contains(kw),
            )
            .toList();
      }

      final pagedItems = items.take(pageSize).toList();
      final nextCursor = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PagedResult<Job>(
        items: pagedItems,
        nextCursor: nextCursor,
        hasMore: snapshot.docs.length >= pageSize,
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

  // ── 6. Streams & Batch Fetching (Home Sections & Categories) ───────────────

  /// Fetches latest active jobs once (default 10 for Home).
  Future<List<Job>> getActiveJobs({int limit = 10}) async {
    try {
      final snap = await _col
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('postedAt', descending: true)
          .limit(limit * 2)
          .get();
      return snap.docs
          .map(Job.fromFirestore)
          .where((j) =>
              j.status == JobStatus.active &&
              j.verification.state == VerificationState.verified &&
              j.applyUrl.isNotEmpty,
          )
          .take(limit)
          .toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Real-time stream of latest active jobs (backed by one-time get to avoid open listeners).
  Stream<List<Job>> watchActiveJobs({int limit = 10}) {
    return Stream.fromFuture(getActiveJobs(limit: limit));
  }

  /// Fetches Technical active verified jobs once (default 10 for Home).
  Future<List<Job>> getTechnicalJobs({int limit = 10}) async {
    try {
      final snap = await _col
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('postedAt', descending: true)
          .limit(limit * 2)
          .get();
      return snap.docs
          .map(Job.fromFirestore)
          .where(
            (j) =>
                j.status == JobStatus.active &&
                j.verification.state == VerificationState.verified &&
                j.applyUrl.isNotEmpty &&
                (j.jobType == JobType.fullTime ||
                    j.category?.toLowerCase().contains('software') == true ||
                    j.category?.toLowerCase().contains('data') == true ||
                    j.category?.toLowerCase().contains('tech') == true ||
                    j.category?.toLowerCase().contains('cloud') == true),
          )
          .take(limit)
          .toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Stream of Technical active verified jobs (backed by one-time get).
  Stream<List<Job>> watchTechnicalJobs({int limit = 10}) {
    return Stream.fromFuture(getTechnicalJobs(limit: limit));
  }

  /// Fetches Non-Technical active verified jobs once (default 10 for Home).
  Future<List<Job>> getNonTechnicalJobs({int limit = 10}) async {
    try {
      final snap = await _col
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('postedAt', descending: true)
          .limit(limit * 2)
          .get();
      return snap.docs
          .map(Job.fromFirestore)
          .where(
            (j) =>
                j.status == JobStatus.active &&
                j.verification.state == VerificationState.verified &&
                j.applyUrl.isNotEmpty &&
                (j.category?.toLowerCase().contains('hr') == true ||
                    j.category?.toLowerCase().contains('finance') == true ||
                    j.category?.toLowerCase().contains('marketing') == true ||
                    j.category?.toLowerCase().contains('sales') == true ||
                    j.category?.toLowerCase().contains('operations') == true ||
                    j.category?.toLowerCase().contains('support') == true ||
                    j.category?.toLowerCase().contains('management') == true),
          )
          .take(limit)
          .toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Stream of Non-Technical active verified jobs (backed by one-time get).
  Stream<List<Job>> watchNonTechnicalJobs({int limit = 10}) {
    return Stream.fromFuture(getNonTechnicalJobs(limit: limit));
  }

  /// Fetches Fresher Opportunities once (default 10 for Home).
  Future<List<Job>> getFresherJobs({int limit = 10}) async {
    try {
      final snap = await _col
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('postedAt', descending: true)
          .limit(limit * 2)
          .get();
      return snap.docs
          .map(Job.fromFirestore)
          .where(
            (j) =>
                j.status == JobStatus.active &&
                j.verification.state == VerificationState.verified &&
                j.applyUrl.isNotEmpty &&
                (j.expMin == null ||
                    j.expMin == 0 ||
                    j.expLevel == ExperienceLevel.entryLevel),
          )
          .take(limit)
          .toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Stream of Fresher Opportunities (backed by one-time get).
  Stream<List<Job>> watchFresherJobs({int limit = 10}) {
    return Stream.fromFuture(getFresherJobs(limit: limit));
  }

  /// Fetches active verified jobs near a given preferred city once (default 10 for Home).
  Future<List<Job>> getNearLocationJobs(String city, {int limit = 10}) async {
    try {
      final snap = await _col
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('postedAt', descending: true)
          .limit(limit * 2)
          .get();
      return snap.docs
          .map(Job.fromFirestore)
          .where(
            (j) =>
                j.status == JobStatus.active &&
                j.verification.state == VerificationState.verified &&
                j.applyUrl.isNotEmpty &&
                (j.city?.toLowerCase() == city.toLowerCase() ||
                    j.locations.any(
                      (l) => l.toLowerCase() == city.toLowerCase(),
                    ) ||
                    j.workMode == WorkMode.remote),
          )
          .take(limit)
          .toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Stream of active verified jobs near a given preferred city (backed by one-time get).
  Stream<List<Job>> watchNearLocationJobs(String city, {int limit = 10}) {
    return Stream.fromFuture(getNearLocationJobs(city, limit: limit));
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
