// lib/data/repositories/search_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo/demo_provider.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/job_query.dart';
import '../services/firebase_service.dart';

/// Result from AI search query parsing.
class ParseQueryResult {
  const ParseQueryResult({
    required this.query,
    this.remainingQuota,
    this.fallbackNotice,
  });

  final JobQuery query;
  final int? remainingQuota;
  final String? fallbackNotice;
}

/// Provider for [SearchRepository].
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final isDemo = ref.watch(isDemoModeProvider);
  if (isDemo) {
    return MockSearchRepository();
  }
  return SearchRepository(
    ref.watch(cloudFunctionsProvider),
    ref.watch(firestoreProvider),
  );
});

class SearchRepository {
  SearchRepository([this._functions, this._firestore]);

  final FirebaseFunctions? _functions;
  final FirebaseFirestore? _firestore;

  /// Fetches remaining AI search quota for the current user today (out of 20).
  Future<int> getRemainingAiQuota(String uid) async {
    if (_firestore == null) return 20;
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final snap = await _firestore!
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection('aiUsage')
          .doc('search_$today')
          .get();

      final count = (snap.data()?['count'] as num?)?.toInt() ?? 0;
      return (20 - count).clamp(0, 20);
    } catch (_) {
      return 20;
    }
  }

  /// Calls Cloud Function `parseSearchQuery` to parse natural language query into filters.
  /// Never queries Gemini directly; results come purely as structured filters.
  Future<ParseQueryResult> parseQuery(String queryText, {String? uid}) async {
    try {
      if (_functions == null) {
        return const ParseQueryResult(query: JobQuery());
      }

      final callable = _functions!.httpsCallable('parseSearchQuery');
      final result = await callable.call<Map<String, dynamic>>({
        'query': queryText.trim(),
      });

      final data = Map<String, dynamic>.from(result.data);
      final jobQuery = JobQuery.fromParsedAi(data);

      int? remaining;
      if (uid != null) {
        remaining = await getRemainingAiQuota(uid);
      }

      String? fallbackNotice;
      if (jobQuery.fallback) {
        fallbackNotice =
            'AI search limit reached or query was processed via keyword fallback.';
      }

      return ParseQueryResult(
        query: jobQuery,
        remainingQuota: remaining,
        fallbackNotice: fallbackNotice,
      );
    } catch (e, st) {
      // Graceful fallback to keyword search on any error
      final fallbackQuery = JobQuery(
        keyword: queryText.trim(),
        fallback: true,
        isAiInterpreted: false,
      );
      return ParseQueryResult(
        query: fallbackQuery,
        fallbackNotice:
            'AI interpretation temporarily unavailable. Defaulted to standard keyword search.',
      );
    }
  }
}

class MockSearchRepository extends SearchRepository {
  MockSearchRepository() : super();

  int _usedToday = 2;

  @override
  Future<int> getRemainingAiQuota(String uid) async {
    return (20 - _usedToday).clamp(0, 20);
  }

  @override
  Future<ParseQueryResult> parseQuery(String queryText, {String? uid}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final lower = queryText.toLowerCase();

    _usedToday++;
    final remaining = (20 - _usedToday).clamp(0, 20);

    // Mock natural language parsing rules
    final titles = <String>[];
    final skills = <String>[];
    String? city;
    String? workMode;
    String? experienceLevel;
    String? category;

    if (lower.contains('java')) skills.add('Java');
    if (lower.contains('react')) skills.add('React');
    if (lower.contains('python')) skills.add('Python');
    if (lower.contains('sql')) skills.add('SQL');

    if (lower.contains('kolkata')) city = 'Kolkata';
    if (lower.contains('bangalore') || lower.contains('bengaluru')) city = 'Bengaluru';
    if (lower.contains('mumbai')) city = 'Mumbai';
    if (lower.contains('delhi') || lower.contains('ncr')) city = 'Delhi';

    if (lower.contains('developer') || lower.contains('engineer')) {
      titles.add('Software Engineer');
    }
    if (lower.contains('marketing')) {
      category = 'Marketing';
      titles.add('Marketing Specialist');
    }

    if (lower.contains('remote')) workMode = 'REMOTE';
    if (lower.contains('hybrid')) workMode = 'HYBRID';
    if (lower.contains('onsite')) workMode = 'ONSITE';

    if (lower.contains('fresher') || lower.contains('entry') || lower.contains('intern')) {
      experienceLevel = 'Fresher';
    }

    final query = JobQuery(
      titles: titles,
      skills: skills,
      city: city,
      workMode: workMode,
      experienceLevel: experienceLevel,
      category: category,
      isAiInterpreted: true,
      fallback: false,
    );

    return ParseQueryResult(
      query: query,
      remainingQuota: remaining,
    );
  }
}
