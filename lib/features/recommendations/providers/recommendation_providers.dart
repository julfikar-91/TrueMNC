// lib/features/recommendations/providers/recommendation_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/job.dart';
import '../../../data/models/recommendation.dart';
import '../../../data/models/user_doc.dart';
import '../../../data/repositories/jobs_repository.dart';
import '../../../data/repositories/recommendation_repository.dart';
import '../../auth/providers/auth_providers.dart';

/// Provider for current UserDoc.
final currentUserProvider = Provider<UserDoc?>((ref) {
  return ref.watch(userDocProvider).value;
});

/// Stream provider for top recommendations.
final topRecommendationsProvider = StreamProvider.autoDispose<List<Recommendation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(recommendationRepositoryProvider).watchRecommendations(user.uid, limit: 10);
});

/// Stream provider for skill-based matches.
final skillMatchesProvider = StreamProvider.autoDispose<List<Recommendation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(recommendationRepositoryProvider).watchSkillMatches(user.uid, limit: 10);
});

/// Stream provider for education-based matches.
final educationMatchesProvider = StreamProvider.autoDispose<List<Recommendation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(recommendationRepositoryProvider).watchEducationMatches(user.uid, limit: 10);
});

/// Stream provider for location-based matches.
final locationMatchesProvider = StreamProvider.autoDispose<List<Recommendation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(recommendationRepositoryProvider).watchLocationMatches(user.uid, limit: 10);
});

/// Stream provider for recently matching recommendations.
final recentlyMatchingProvider = StreamProvider.autoDispose<List<Recommendation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(recommendationRepositoryProvider).watchRecentlyMatching(user.uid, limit: 10);
});

/// Helper provider that bundles a list of recommendations with their full [Job] models.
final populatedRecommendationsProvider =
    FutureProvider.family<List<({Recommendation recommendation, Job job})>, List<Recommendation>>(
  (ref, recList) async {
    if (recList.isEmpty) return const [];
    final jobRepo = ref.watch(jobsRepositoryProvider);
    final jobIds = recList.map((r) => r.jobId ?? r.id ?? '').where((id) => id.isNotEmpty).toList();
    final jobs = await jobRepo.getJobsByIds(jobIds);
    final jobMap = {for (final j in jobs) if (j.id != null) j.id!: j};

    final result = <({Recommendation recommendation, Job job})>[];
    for (final rec in recList) {
      final jId = rec.jobId ?? rec.id;
      final job = jobMap[jId];
      if (job != null && job.status.name.toUpperCase() == 'ACTIVE') {
        result.add((recommendation: rec, job: job));
      }
    }
    return result;
  },
);

/// Match card data provider for a single job details view.
/// Reads cached recommendation if available, otherwise falls back to callable `scoreForUser`.
final jobMatchScoreProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, jobId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null; // Guest user

  final recRepo = ref.watch(recommendationRepositoryProvider);
  final cached = await recRepo.getCachedRecommendation(user.uid, jobId);
  if (cached != null) {
    return {
      'score': cached.score,
      'label': cached.score >= 80
          ? 'Strong'
          : cached.score >= 65
              ? 'Good'
              : 'Possible',
      'breakdown': {
        'skills': cached.breakdown.skills,
        'education': cached.breakdown.education,
        'experience': cached.breakdown.experience,
        'location': cached.breakdown.location,
        'preference': cached.breakdown.preference,
      },
      'matchedSkills': cached.matchedSkills,
      'missingSkills': cached.missingSkills,
      'niceToHave': <String>[],
      'reasons': cached.reasons,
      'gaps': <String>[],
      'flags': <String>[],
      'cached': true,
    };
  }

  // On-demand computation fallback
  return recRepo.scoreForUser(jobId);
});
