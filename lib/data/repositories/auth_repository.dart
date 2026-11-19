// lib/data/repositories/auth_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/auth_result.dart';
import '../models/user_doc.dart';
import '../services/firebase_service.dart';

// ── Providers ────────────────────────────────────────────────────────────────

/// Primary auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

/// Streams the Firebase Auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Streams the user's role from Firebase ID token custom claims (default USER).
/// Client can NEVER set or write role.
final claimsProvider = StreamProvider<UserRole>((ref) async* {
  final authRepo = ref.watch(authRepositoryProvider);
  await for (final user in authRepo.idTokenChanges) {
    if (user == null) {
      yield UserRole.user;
    } else {
      try {
        final tokenResult = await user.getIdTokenResult(false);
        final roleStr = tokenResult.claims?['role'] as String?;
        yield UserRoleX.fromClaim(roleStr);
      } catch (_) {
        yield UserRole.user;
      }
    }
  }
});

/// Streams the current user's `/users/{uid}` document from Firestore.
final userDocProvider = StreamProvider<UserDoc?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authRepositoryProvider).watchUserDoc(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// Represents the first-launch app initialization / bootstrap state.
/// Resolves true if ready, or error/false if initialization / initial network fails.
final appBootstrapProvider = AsyncNotifierProvider<AppBootstrapNotifier, bool>(
  AppBootstrapNotifier.new,
);

class AppBootstrapNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // Basic startup check: ensures Firebase auth/firestore are responsive
    try {
      final auth = ref.read(firebaseAuthProvider);
      // Wait for initial auth state to resolve
      await auth.authStateChanges().first.timeout(
            const Duration(seconds: 10),
            onTimeout: () => auth.currentUser,
          );
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = ref.read(firebaseAuthProvider);
      await auth.authStateChanges().first.timeout(const Duration(seconds: 10));
      return true;
    });
  }
}

// ── Repository Implementation ────────────────────────────────────────────────

class AuthRepository {
  AuthRepository(this._auth, this._db, {GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email']);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();
  User? get currentUser => _auth.currentUser;

  /// Signs up with email + password.
  /// Sets displayName and creates `users/{uid}` with ONLY:
  /// `name`, `email`, `onboarding_done: false`, `profile_confirmed: false`, `createdAt`
  /// (NEVER writes role).
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Set display name on Firebase Auth profile
        await user.updateDisplayName(name.trim());

        // Create initial Firestore user document with strictly allowed fields
        await _db.collection(AppConstants.usersCollection).doc(user.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'onboarding_done': false,
          'profile_confirmed': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send verification email to email/password registrant
        try {
          await user.sendEmailVerification();
        } catch (_) {
          // Non-critical if rate-limited; user can resend from verification screen
        }
      }

      return credential;
    } on FirebaseAuthException catch (e, st) {
      if (e.code == 'email-already-in-use') {
        throw const DuplicateEmailException();
      }
      throw handleException(e, st);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Signs in with email and password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e, st) {
      throw handleException(e, st);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Initiates Google Sign-In with account linking detection.
  /// If the email exists with password provider, returns [GoogleSignInNeedsLinking].
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const GoogleSignInCancelled();
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      // If user is brand new via Google, initialise the user document in Firestore
      if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        await _db.collection(AppConstants.usersCollection).doc(user.uid).set({
          'name': user.displayName ?? googleUser.displayName ?? '',
          'email': user.email ?? googleUser.email,
          'onboarding_done': false,
          'profile_confirmed': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true),);
      }

      return GoogleSignInSuccess(userCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' ||
          e.code == 'credential-already-in-use') {
        return GoogleSignInNeedsLinking(
          email: e.email ?? '',
          credential: e.credential ??
              GoogleAuthProvider.credential(
                accessToken: null,
                idToken: null,
              ),
        );
      }
      throw handleException(e);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Sends verification email to current user.
  Future<void> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const UnauthenticatedException();
      await user.sendEmailVerification();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Reloads user's auth profile to check updated email verification / custom claims.
  Future<void> reloadUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await user.reload();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e, st) {
      // Avoid enumeration: do not disclose whether email exists
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return; // Silent return — same user experience
      }
      throw handleException(e, st);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Refreshes the ID token and returns the latest claims.
  Future<IdTokenResult?> refreshIdToken({bool force = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return await user.getIdTokenResult(force);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Watches the `/users/{uid}` document as a reactive stream.
  Stream<UserDoc?> watchUserDoc(String uid) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserDoc.fromMap(snapshot.data()!, snapshot.id);
    });
  }
}
