// lib/data/repositories/resume_repository.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo/demo_provider.dart';
import '../../core/demo/mock_repositories.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/resume_model.dart';
import '../services/firebase_service.dart';

final resumeRepositoryProvider = Provider<ResumeRepository>((ref) {
  final isDemo = ref.watch(isDemoModeProvider);
  if (isDemo) {
    return MockResumeRepository();
  }
  return ResumeRepository(
    ref.watch(firebaseStorageProvider),
    ref.watch(firestoreProvider),
    ref.watch(cloudFunctionsProvider),
  );
});

final watchResumeProvider = StreamProvider.family<ResumeDoc?, String>((ref, resumeId) {
  final repo = ref.watch(resumeRepositoryProvider);
  return repo.watchResume(resumeId);
});

final watchResumeParseProvider =
    StreamProvider.family<ParsedResumeDraft?, String>((ref, resumeId) {
  final repo = ref.watch(resumeRepositoryProvider);
  return repo.watchResumeParse(resumeId);
});

/// Repository orchestrating resume upload, Firestore status streaming,
/// and server-side Cloud Function callables for parsing, confirming, and deleting resumes.
///
/// Follows non-negotiable security principles:
/// - Client never sets verification state.
/// - Storage download URLs are NEVER exposed to the client or UI.
/// - All writes to users/{uid} subcollections and status transitions go through server callables.
class ResumeRepository {
  ResumeRepository(this._storage, this._firestore, this._functions);

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  // ── 1. Resumable Upload to Firebase Storage ─────────────────────────────────

  /// Uploads resume binary bytes directly to `resumes/{uid}/{resumeId}.{ext}`.
  /// Reports real-time upload progress.
  /// Never generates or exposes public download URLs.
  Future<String> uploadResumeFile({
    required String uid,
    required String resumeId,
    required Uint8List bytes,
    required String extension,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final safeExt = extension.replaceAll('.', '').toLowerCase();
      final storagePath = 'resumes/$uid/$resumeId.$safeExt';
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'uid': uid,
          'resumeId': resumeId,
        },
      );

      final uploadTask = ref.putData(bytes, metadata);

      uploadTask.snapshotEvents.listen((event) {
        final total = event.totalBytes;
        if (total > 0 && onProgress != null) {
          onProgress(event.bytesTransferred / total);
        }
      });

      await uploadTask;
      return storagePath;
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 2. Create Initial Resume Document in Firestore ─────────────────────────

  /// Creates document in `resumes/{resumeId}` with initial status UPLOADED.
  Future<void> createResumeDoc({
    required String resumeId,
    required String uid,
    required String storagePath,
    required int fileSize,
    required String mimeType,
  }) async {
    try {
      final batch = _firestore.batch();
      final resumeRef = _firestore.collection('resumes').doc(resumeId);
      final userRef =
          _firestore.collection(AppConstants.usersCollection).doc(uid);

      batch.set(
        resumeRef,
        {
          'id': resumeId,
          'uid': uid,
          'storagePath': storagePath,
          'status': 'UPLOADED',
          'progress': 'uploading',
          'fileSize': fileSize,
          'mimeType': mimeType,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Mark user document flags for router synchronization
      batch.set(
        userRef,
        {
          'resume_onboarding_done': true,
          'resume_parse_in_progress': true,
          'current_resume_id': resumeId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 3. Call Server-Side parseResume Callable ────────────────────────────────

  /// Triggers server-side Gen 2 Cloud Function to parse resume.
  Future<Map<String, dynamic>> parseResume({
    required String resumeId,
    String? storagePath,
  }) async {
    try {
      final callable = _functions.httpsCallable('parseResume');
      final result = await callable.call<Map<String, dynamic>>({
        'resumeId': resumeId,
        if (storagePath != null) 'storagePath': storagePath,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 4. Watch Resume & Parsed Draft Documents ───────────────────────────────

  /// Live Firestore stream of `resumes/{resumeId}`.
  Stream<ResumeDoc?> watchResume(String resumeId) {
    try {
      return _firestore
          .collection('resumes')
          .doc(resumeId)
          .snapshots()
          .map((snap) {
        if (!snap.exists) return null;
        return ResumeDoc.fromFirestore(snap);
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Live Firestore stream of `resumeParses/{resumeId}`.
  Stream<ParsedResumeDraft?> watchResumeParse(String resumeId) {
    try {
      return _firestore
          .collection('resumeParses')
          .doc(resumeId)
          .snapshots()
          .map((snap) {
        if (!snap.exists) return null;
        return ParsedResumeDraft.fromFirestore(snap);
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 5. Confirm Profile Callable ─────────────────────────────────────────────

  /// Invokes `confirmProfile` callable to apply accepted draft to user profile.
  Future<Map<String, dynamic>> confirmProfile({
    required String resumeId,
    Map<String, dynamic>? confirmedProfile,
  }) async {
    try {
      final callable = _functions.httpsCallable('confirmProfile');
      final result = await callable.call<Map<String, dynamic>>({
        'resumeId': resumeId,
        if (confirmedProfile != null) 'confirmedProfile': confirmedProfile,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 6. Delete Resume Callable ───────────────────────────────────────────────

  /// Invokes `deleteResume` callable to clean up Storage file and parsed draft.
  Future<void> deleteResume(String resumeId) async {
    try {
      final callable = _functions.httpsCallable('deleteResume');
      await callable.call<dynamic>({
        'resumeId': resumeId,
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}
