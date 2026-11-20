// lib/data/repositories/recommendation_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo/demo_provider.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/recommendation.dart';
import '../services/firebase_service.dart';
import 'paged_controller.dart';

/// Provider for [RecommendationRepository].
final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  final isDemo = ref.watch(isDemoModeProvider);
  if (isDemo) {
    return MockRecommendationRepository();
  }
  return RecommendationRepository(
    ref.watch(firestoreProvider),
    ref.watch(cloudFunctionsProvider),
  );
});

/// Repository managing candidate recommendations at `/users/{uid}/recommendations`.
///
/// Follows non-negotiable principles:
/// - Server-only write: Recommendations are computed and saved exclusively server-side.
/// - Client can read its own recommendations via Firestore rules.
/// - Triggers on-demand calculation via Gen 2 Cloud Function `scoreForUser`.
/// - Triggers manual fanout refresh via `refreshRecommendations`.
class RecommendationRepository {
  RecommendationRepository([this._firestore, this._functions]);

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  CollectionReference<Map<String, dynamic>> _recsCol(String uid) => _firestore!
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection('recommendations');

  // ── 1. Real-time Streams ────────────────────────────────────────────────────

  /// Fetches top recommendations for a candidate ordered by score descending once.
  Future<List<Recommendation>> getRecommendations(
    String uid, {
    int limit = 10,
  }) async {
    try {
      final snap = await _recsCol(uid)
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(Recommendation.fromFirestore).toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams top recommendations for a candidate (backed by one-time get).
  Stream<List<Recommendation>> watchRecommendations(
    String uid, {
    int limit = 10,
  }) {
    return Stream.fromFuture(getRecommendations(uid, limit: limit));
  }

  /// Fetches recommendations with high skill match breakdown once.
  Future<List<Recommendation>> getSkillMatches(
    String uid, {
    int limit = 10,
  }) async {
    try {
      final snap = await _recsCol(uid)
          .orderBy('breakdown.skills', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(Recommendation.fromFirestore).toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams recommendations with high skill match breakdown (backed by one-time get).
  Stream<List<Recommendation>> watchSkillMatches(
    String uid, {
    int limit = 10,
  }) {
    return Stream.fromFuture(getSkillMatches(uid, limit: limit));
  }

  /// Fetches recommendations with high education match breakdown once.
  Future<List<Recommendation>> getEducationMatches(
    String uid, {
    int limit = 10,
  }) async {
    try {
      final snap = await _recsCol(uid)
          .orderBy('breakdown.education', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(Recommendation.fromFirestore).toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams recommendations with high education match breakdown (backed by one-time get).
  Stream<List<Recommendation>> watchEducationMatches(
    String uid, {
    int limit = 10,
  }) {
    return Stream.fromFuture(getEducationMatches(uid, limit: limit));
  }

  /// Fetches recommendations with high location match breakdown once.
  Future<List<Recommendation>> getLocationMatches(
    String uid, {
    int limit = 10,
  }) async {
    try {
      final snap = await _recsCol(uid)
          .orderBy('breakdown.location', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(Recommendation.fromFirestore).toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams recommendations with high location match breakdown (backed by one-time get).
  Stream<List<Recommendation>> watchLocationMatches(
    String uid, {
    int limit = 10,
  }) {
    return Stream.fromFuture(getLocationMatches(uid, limit: limit));
  }

  /// Fetches recently matched recommendations once.
  Future<List<Recommendation>> getRecentlyMatching(
    String uid, {
    int limit = 10,
  }) async {
    try {
      final snap = await _recsCol(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(Recommendation.fromFirestore).toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Streams recently matched recommendations (backed by one-time get).
  Stream<List<Recommendation>> watchRecentlyMatching(
    String uid, {
    int limit = 10,
  }) {
    return Stream.fromFuture(getRecentlyMatching(uid, limit: limit));
  }

  // ── 2. Cursor-Based Pagination ──────────────────────────────────────────────

  /// Fetches paginated recommendations cursor-based (20 per page).
  Future<PagedResult<Recommendation>> getPagedRecommendations(
    String uid, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _recsCol(uid).orderBy('score', descending: true).limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map(Recommendation.fromFirestore).toList();
      final nextCursor = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PagedResult<Recommendation>(
        items: items,
        nextCursor: nextCursor,
        hasMore: items.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 3. Single Recommendation by Job ID ─────────────────────────────────────

  /// Fetches single cached recommendation from Firestore subcollection.
  Future<Recommendation?> getCachedRecommendation(String uid, String jobId) async {
    try {
      final doc = await _recsCol(uid).doc(jobId).get();
      if (!doc.exists) return null;
      return Recommendation.fromFirestore(doc);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 4. Callables ────────────────────────────────────────────────────────────

  /// Calls Cloud Function `scoreForUser` to compute or retrieve match score on demand.
  Future<Map<String, dynamic>> scoreForUser(String jobId) async {
    try {
      final callable = _functions!.httpsCallable('scoreForUser');
      final res = await callable.call<Map<String, dynamic>>({'jobId': jobId});
      return Map<String, dynamic>.from(res.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Calls Cloud Function `refreshRecommendations` with 5-minute rate limit.
  /// Returns null on success or user-friendly rate limit message if throttled.
  Future<String?> refreshRecommendations() async {
    try {
      final callable = _functions!.httpsCallable('refreshRecommendations');
      final res = await callable.call<Map<String, dynamic>>({});
      final data = Map<String, dynamic>.from(res.data);

      if (data['status'] == 'RATE_LIMITED') {
        return (data['message'] as String?) ??
            'You can only refresh recommendations once every 5 minutes.';
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return e.message ??
            'You can only refresh recommendations once every 5 minutes.';
      }
      throw handleException(e, StackTrace.current);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 5. AI Deep Match ────────────────────────────────────────────────────────

  /// Fetches remaining Deep Matches for today (out of 3).
  Future<int> getRemainingDeepMatches(String uid) async {
    if (_firestore == null) return 3;
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final snap = await _firestore!
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection('aiUsage')
          .doc('deepMatch_$today')
          .get();

      final count = (snap.data()?['count'] as num?)?.toInt() ?? 0;
      return (3 - count).clamp(0, 3);
    } catch (_) {
      return 3;
    }
  }

  /// Triggers AI Deep Match (max 3/day) via Cloud Function `deepMatch`.
  /// Note: Only a compact summary (skills, level, preferences) is sent, never the resume file.
  Future<Map<String, dynamic>> triggerDeepMatch() async {
    try {
      if (_functions == null) throw Exception('Firebase Functions unavailable');

      final callable = _functions!.httpsCallable('deepMatch');
      final res = await callable.call<Map<String, dynamic>>({});
      return Map<String, dynamic>.from(res.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}

// ── Demo / Mock Implementation ────────────────────────────────────────────────
class MockRecommendationRepository extends RecommendationRepository {
  MockRecommendationRepository() : super();

  int _deepMatchUsedToday = 0;

  final List<Recommendation> _mockRecs = [
    const Recommendation(
      id: 'job_junior_java',
      jobId: 'job_junior_java',
      score: 84.0,
      breakdown: ScoreBreakdown(
        skills: 80,
        education: 100,
        experience: 50,
        location: 100,
        preference: 100,
      ),
      matchedSkills: ['Java', 'SQL', 'React'],
      missingSkills: ['PostgreSQL'],
      reasons: [
        'Skills strongly align with Junior Java Developer',
        'B.Tech CSE satisfies degree requirement',
        'Location matches Kolkata',
      ],
      scoreVersion: 'v1',
      isNew: true,
    ),
  ];

  @override
  Stream<List<Recommendation>> watchRecommendations(String uid, {int limit = 10}) {
    return Stream.value(_mockRecs.take(limit).toList());
  }

  @override
  Stream<List<Recommendation>> watchSkillMatches(String uid, {int limit = 10}) {
    return Stream.value(_mockRecs.take(limit).toList());
  }

  @override
  Stream<List<Recommendation>> watchEducationMatches(String uid, {int limit = 10}) {
    return Stream.value(_mockRecs.take(limit).toList());
  }

  @override
  Stream<List<Recommendation>> watchLocationMatches(String uid, {int limit = 10}) {
    return Stream.value(_mockRecs.take(limit).toList());
  }

  @override
  Stream<List<Recommendation>> watchRecentlyMatching(String uid, {int limit = 10}) {
    return Stream.value(_mockRecs.take(limit).toList());
  }

  @override
  Future<PagedResult<Recommendation>> getPagedRecommendations(
    String uid, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    return PagedResult(
      items: _mockRecs.take(pageSize).toList(),
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<Recommendation?> getCachedRecommendation(String uid, String jobId) async {
    return _mockRecs.firstWhere((r) => r.jobId == jobId, orElse: () => _mockRecs.first);
  }

  @override
  Future<Map<String, dynamic>> scoreForUser(String jobId) async {
    return {
      'score': 84.0,
      'label': 'Strong',
      'breakdown': {
        'skills': 80,
        'education': 100,
        'experience': 50,
        'location': 100,
        'preference': 100,
      },
      'matchedSkills': ['Java', 'SQL', 'React'],
      'missingSkills': ['PostgreSQL'],
      'niceToHave': ['React'],
      'reasons': ['Strong skills match', 'Education meets level+field in CSE'],
      'gaps': ['Experience unknown'],
      'flags': ['Add experience for better accuracy'],
      'cached': true,
    };
  }

  @override
  Future<String?> refreshRecommendations() async {
    return null;
  }

  @override
  Future<int> getRemainingDeepMatches(String uid) async {
    return (3 - _deepMatchUsedToday).clamp(0, 3);
  }

  @override
  Future<Map<String, dynamic>> triggerDeepMatch() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_deepMatchUsedToday >= 3) {
      throw Exception('Daily Deep Match limit reached (max 3 per day).');
    }
    _deepMatchUsedToday++;
    for (var i = 0; i < _mockRecs.length; i++) {
      final rec = _mockRecs[i];
      final reasons = List<String>.from(rec.reasons);
      if (!reasons.any((r) => r.startsWith('[AI]'))) {
        reasons.insert(0, '[AI] Strong cultural & technical fit based on confirmed skills');
      }
      _mockRecs[i] = rec.copyWith(reasons: reasons);
    }
    return {
      'success': true,
      'updated': _mockRecs.length,
      'remaining': 3 - _deepMatchUsedToday,
    };
  }
}
