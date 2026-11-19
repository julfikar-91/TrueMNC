// lib/features/admin/config/providers/system_config_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/admin_repository.dart';

/// Streams current scoring configuration document from Firestore.
final scoringConfigStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.watchScoringConfig();
});

/// Streams current app configuration document from Firestore.
final appConfigStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.watchAppConfig();
});

/// Fetches historical versions for config documents ('app' or 'scoring_v1').
final configVersionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, configDoc) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getConfigVersions(configDoc);
});
