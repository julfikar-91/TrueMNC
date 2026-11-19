// lib/data/repositories/profile_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/app_user.dart';
import '../models/profile_models.dart';
import '../services/firebase_service.dart';

/// Provider for [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(firestoreProvider));
});

/// Repository managing user profile document and subcollections at `/users/{uid}`.
///
/// Follows non-negotiable security rules:
/// - Client can NEVER write `role`, `profile_completion`, `matchKeys`, or
///   `profile_confirmed_by_system`.
/// - All write operations strip forbidden fields before submitting to Firestore.
class ProfileRepository {
  ProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection(AppConstants.usersCollection).doc(uid);

  CollectionReference<Map<String, dynamic>> _subCollection(
    String uid,
    String subcollection,
  ) =>
      _userDoc(uid).collection(subcollection);

  // ── 1. User Document ─────────────────────────────────────────────────────────

  /// Streams the user profile document.
  Stream<AppUser?> watchUser(String uid) {
    try {
      return _userDoc(uid).snapshots().map((snap) {
        if (!snap.exists) return null;
        return AppUser.fromFirestore(snap);
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Gets current user profile document once.
  Future<AppUser?> getUser(String uid) async {
    try {
      final snap = await _userDoc(uid).get();
      if (!snap.exists) return null;
      return AppUser.fromFirestore(snap);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Updates allowed profile fields.
  /// Strictly prevents client from writing forbidden fields (role, completion, matchKeys).
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      final safeData = Map<String, dynamic>.from(data);

      // SECURITY GUARD: Strip all server-controlled keys
      const forbiddenKeys = [
        'role',
        'profile_completion',
        'profileCompletion',
        'profile_confirmed_by_system',
        'matchKeys',
        'fcm_tokens',
        'fcmTokens',
        'id',
        'uid',
      ];
      for (final key in forbiddenKeys) {
        safeData.remove(key);
      }

      safeData['updatedAt'] = FieldValue.serverTimestamp();

      await _userDoc(uid).set(safeData, SetOptions(merge: true));
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 2. Education Subcollection ──────────────────────────────────────────────

  Stream<List<Education>> watchEducation(String uid) {
    try {
      return _subCollection(uid, 'education')
          .orderBy('startDate', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(Education.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<String> addEducation(String uid, Education education) async {
    try {
      final docRef = _subCollection(uid, 'education').doc();
      final data = education.toFirestore();
      await docRef.set(data);
      return docRef.id;
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> updateEducation(String uid, Education education) async {
    if (education.id == null || education.id!.isEmpty) {
      throw const ValidationException('Education ID is required for update.');
    }
    try {
      await _subCollection(uid, 'education')
          .doc(education.id)
          .set(education.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> deleteEducation(String uid, String educationId) async {
    try {
      await _subCollection(uid, 'education').doc(educationId).delete();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 3. Skills Subcollection ─────────────────────────────────────────────────

  Stream<List<SkillItem>> watchSkills(String uid) {
    try {
      return _subCollection(uid, 'skills')
          .snapshots()
          .map((snap) => snap.docs.map(SkillItem.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> addSkill(String uid, SkillItem skill) async {
    try {
      // Use normalized skill name as doc ID to prevent duplicates
      final docId = skill.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      await _subCollection(uid, 'skills').doc(docId).set(skill.toFirestore());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> deleteSkill(String uid, String skillDocId) async {
    try {
      await _subCollection(uid, 'skills').doc(skillDocId).delete();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 4. Experience Subcollection ─────────────────────────────────────────────

  Stream<List<Experience>> watchExperience(String uid) {
    try {
      return _subCollection(uid, 'experience')
          .orderBy('startDate', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(Experience.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<String> addExperience(String uid, Experience experience) async {
    try {
      final docRef = _subCollection(uid, 'experience').doc();
      await docRef.set(experience.toFirestore());
      return docRef.id;
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> updateExperience(String uid, Experience experience) async {
    if (experience.id == null || experience.id!.isEmpty) {
      throw const ValidationException('Experience ID is required for update.');
    }
    try {
      await _subCollection(uid, 'experience')
          .doc(experience.id)
          .set(experience.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> deleteExperience(String uid, String experienceId) async {
    try {
      await _subCollection(uid, 'experience').doc(experienceId).delete();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 5. Projects Subcollection ───────────────────────────────────────────────

  Stream<List<Project>> watchProjects(String uid) {
    try {
      return _subCollection(uid, 'projects')
          .snapshots()
          .map((snap) => snap.docs.map(Project.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<String> addProject(String uid, Project project) async {
    try {
      final docRef = _subCollection(uid, 'projects').doc();
      await docRef.set(project.toFirestore());
      return docRef.id;
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> updateProject(String uid, Project project) async {
    if (project.id == null || project.id!.isEmpty) {
      throw const ValidationException('Project ID is required for update.');
    }
    try {
      await _subCollection(uid, 'projects')
          .doc(project.id)
          .set(project.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> deleteProject(String uid, String projectId) async {
    try {
      await _subCollection(uid, 'projects').doc(projectId).delete();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 6. Certifications Subcollection ─────────────────────────────────────────

  Stream<List<Certification>> watchCertifications(String uid) {
    try {
      return _subCollection(uid, 'certifications')
          .snapshots()
          .map((snap) => snap.docs.map(Certification.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<String> addCertification(String uid, Certification cert) async {
    try {
      final docRef = _subCollection(uid, 'certifications').doc();
      await docRef.set(cert.toFirestore());
      return docRef.id;
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> deleteCertification(String uid, String certId) async {
    try {
      await _subCollection(uid, 'certifications').doc(certId).delete();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 7. Preferences Document ─────────────────────────────────────────────────

  Stream<CareerPreferences?> watchPreferences(String uid) {
    try {
      return _subCollection(uid, 'preferences')
          .doc('main')
          .snapshots()
          .map((snap) {
        if (!snap.exists) return null;
        return CareerPreferences.fromFirestore(snap);
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<CareerPreferences?> getPreferences(String uid) async {
    try {
      final snap = await _subCollection(uid, 'preferences').doc('main').get();
      if (!snap.exists) return null;
      return CareerPreferences.fromFirestore(snap);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Future<void> updatePreferences(String uid, CareerPreferences preferences) async {
    try {
      await _subCollection(uid, 'preferences')
          .doc('main')
          .set(preferences.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}
