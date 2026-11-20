// lib/features/home/providers/home_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/company.dart';
import '../../../data/models/job.dart';
import '../../../data/models/recommendation.dart';
import '../../../data/repositories/company_repository.dart';
import '../../../data/repositories/jobs_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../recommendations/providers/recommendation_providers.dart';

/// Contextual greeting string based on current time of day and candidate name.
final greetingProvider = Provider<String>((ref) {
  final user = ref.watch(userDocProvider).value;
  final hour = DateTime.now().hour;
  final prefix = hour < 12
      ? 'Good morning'
      : hour < 17
          ? 'Good afternoon'
          : 'Good evening';
  final name = user?.name?.split(' ').first;
  if (name != null && name.isNotEmpty) {
    return '$prefix, $name!';
  }
  return '$prefix!';
});

/// Indicates if current user has a fully confirmed profile.
final isProfileConfirmedProvider = Provider<bool>((ref) {
  final user = ref.watch(userDocProvider).value;
  return user != null && user.profileConfirmed;
});

/// Indicates if candidate explicitly confirmed fresher / entry-level status.
final isFresherCandidateProvider = Provider<bool>((ref) {
  final user = ref.watch(userDocProvider).value;
  if (user == null) return false;
  final prefs = user.preferences;
  final careerStage = (prefs?['careerStage'] ?? prefs?['experienceLevel'] ?? '').toString().toLowerCase();
  return user.isFresher == true || careerStage.contains('fresher') || careerStage.contains('entry');
});

/// Candidate's preferred or current city.
final preferredCityProvider = Provider<String?>((ref) {
  final user = ref.watch(userDocProvider).value;
  return user?.location ?? (user?.preferences?['city'] as String?);
});

// ── Personalised Section Providers (Requires confirmed profile) ──────────────

/// Recommended For You (Populated with Job details)
final homeRecommendedJobsProvider =
    FutureProvider.autoDispose<List<({Recommendation recommendation, Job job})>>((ref) async {
  final isConfirmed = ref.watch(isProfileConfirmedProvider);
  if (!isConfirmed) return const [];
  final recs = await ref.watch(topRecommendationsProvider.future);
  return ref.watch(populatedRecommendationsProvider(recs).future);
});

/// Best Skill Matches (Populated with Job details)
final homeSkillMatchesProvider =
    FutureProvider.autoDispose<List<({Recommendation recommendation, Job job})>>((ref) async {
  final isConfirmed = ref.watch(isProfileConfirmedProvider);
  if (!isConfirmed) return const [];
  final recs = await ref.watch(skillMatchesProvider.future);
  return ref.watch(populatedRecommendationsProvider(recs).future);
});

/// Jobs Based on Your Education (Populated with Job details)
final homeEducationJobsProvider =
    FutureProvider.autoDispose<List<({Recommendation recommendation, Job job})>>((ref) async {
  final isConfirmed = ref.watch(isProfileConfirmedProvider);
  if (!isConfirmed) return const [];
  final recs = await ref.watch(educationMatchesProvider.future);
  return ref.watch(populatedRecommendationsProvider(recs).future);
});

// ── Non-Personalised & Filtered Section Providers ───────────────────────────

/// Fresher Opportunities (Only visible if candidate explicitly confirmed fresher)
final homeFresherJobsProvider = StreamProvider.autoDispose<List<Job>>((ref) {
  final isFresher = ref.watch(isFresherCandidateProvider);
  if (!isFresher) return Stream.value(const []);
  return ref.watch(jobsRepositoryProvider).watchFresherJobs(limit: 10);
});

/// Technical Verified Jobs
final homeTechnicalJobsProvider = StreamProvider.autoDispose<List<Job>>((ref) {
  return ref.watch(jobsRepositoryProvider).watchTechnicalJobs(limit: 10);
});

/// Non-Technical Verified Jobs
final homeNonTechnicalJobsProvider = StreamProvider.autoDispose<List<Job>>((ref) {
  return ref.watch(jobsRepositoryProvider).watchNonTechnicalJobs(limit: 10);
});

/// Jobs Near Preferred Location
final homeNearLocationJobsProvider = StreamProvider.autoDispose<List<Job>>((ref) {
  final city = ref.watch(preferredCityProvider);
  if (city == null || city.isEmpty) return Stream.value(const []);
  return ref.watch(jobsRepositoryProvider).watchNearLocationJobs(city, limit: 10);
});

/// Recently Added Verified Jobs
final homeRecentlyAddedJobsProvider = StreamProvider.autoDispose<List<Job>>((ref) {
  return ref.watch(jobsRepositoryProvider).watchActiveJobs(limit: 10);
});

/// Popular Verified Companies
final homePopularCompaniesProvider = StreamProvider.autoDispose<List<Company>>((ref) {
  return ref.watch(companyRepositoryProvider).watchVerifiedCompanies(limit: 10);
});
