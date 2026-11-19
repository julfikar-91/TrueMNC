// lib/data/models/auth_result.dart
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result wrapper for Google Sign-In supporting account linking detection.
sealed class GoogleSignInResult extends Equatable {
  const GoogleSignInResult();
}

/// Sign-in was successful.
final class GoogleSignInSuccess extends GoogleSignInResult {
  const GoogleSignInSuccess(this.userCredential);
  final UserCredential userCredential;

  @override
  List<Object?> get props => [userCredential];
}

/// Email exists with a different provider (e.g. email/password), requiring account linking.
final class GoogleSignInNeedsLinking extends GoogleSignInResult {
  const GoogleSignInNeedsLinking({
    required this.email,
    required this.credential,
    this.message =
        'An account already exists with this email address. Please sign in with your email and password to link your Google account.',
  });

  final String email;
  final AuthCredential credential;
  final String message;

  @override
  List<Object?> get props => [email, credential, message];
}

/// User dismissed the Google Sign-In bottom sheet or modal.
final class GoogleSignInCancelled extends GoogleSignInResult {
  const GoogleSignInCancelled();

  @override
  List<Object?> get props => [];
}
