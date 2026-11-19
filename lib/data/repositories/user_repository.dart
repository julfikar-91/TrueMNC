// lib/data/repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(AppConstants.usersCollection).doc(uid);

  Stream<UserModel?> watchUser(String uid) {
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromJson({...snap.data()!, 'uid': snap.id});
    });
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final snap = await _doc(uid).get();
      if (!snap.exists) return null;
      return UserModel.fromJson({...snap.data()!, 'uid': snap.id});
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Create or update user profile. Role is NEVER written here.
  Future<void> upsertUser(UserModel user) async {
    try {
      final data = user.toJson()
        ..remove('uid') // uid is the doc ID
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await _doc(user.uid).set(data, SetOptions(merge: true));
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}
