// lib/features/admin/administrators/providers/admin_management_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/app_user.dart';
import '../../../../data/repositories/admin_repository.dart';

/// Streams the list of all administrators (users with role ADMIN or SUPER_ADMIN).
final administratorsStreamProvider = StreamProvider<List<AppUser>>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.watchAdministrators();
});

/// Async notifier for performing administrator role changes (add / revoke).
final adminActionControllerProvider =
    StateNotifierProvider<AdminActionController, AsyncValue<void>>((ref) {
  return AdminActionController(ref.watch(adminRepositoryProvider));
});

class AdminActionController extends StateNotifier<AsyncValue<void>> {
  AdminActionController(this._repository) : super(const AsyncValue.data(null));

  final AdminRepository _repository;

  /// Assigns a new role to a user by email or UID.
  Future<void> setUserRole({
    String? email,
    String? uid,
    required String role,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.setUserRole(
        email: email,
        uid: uid,
        role: role,
      );
    });
  }

  /// Revokes an administrator's privileges by downgrading them to standard 'USER'.
  Future<void> revokeAdmin({
    String? email,
    String? uid,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.setUserRole(
        email: email,
        uid: uid,
        role: 'USER',
      );
    });
  }
}
