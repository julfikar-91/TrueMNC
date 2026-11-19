// lib/features/onboarding/providers/onboarding_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/constants.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/firebase_service.dart';

const String kOnboardingSeenKey = 'onboarding_seen';

final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final onboardingNotifierProvider =
    AsyncNotifierProvider<OnboardingNotifier, void>(OnboardingNotifier.new);

class OnboardingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Marks onboarding as seen in SharedPreferences and updates `users/{uid}.onboarding_done`
  /// if user is currently authenticated.
  Future<void> completeOnboarding() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingSeenKey, true);

      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        final db = ref.read(firestoreProvider);
        await db.collection(AppConstants.usersCollection).doc(user.uid).set(
          {
            'onboarding_done': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }
}
