// lib/core/errors/error_handler.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'app_exception.dart';

/// Maps raw exceptions into user-friendly [AppException]s.
/// Strictly avoids account enumeration by mapping all credential-related errors
/// to a single, identical generic message.
AppException mapFirebaseAuthException(FirebaseAuthException error) {
  switch (error.code) {
    // ANTI-ACCOUNT ENUMERATION:
    // Never disclose whether an email exists or if the password was the only mismatch.
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-email':
    case 'user-mismatch':
      return AuthException.invalidCredentials();

    case 'user-disabled':
      return AuthException.accountDisabled();

    case 'email-already-in-use':
      return AuthException.emailAlreadyInUse();

    case 'too-many-requests':
      return AuthException.tooManyRequests();

    case 'network-request-failed':
      return const NetworkException();

    case 'requires-recent-login':
      return const AuthException(
        'This action requires recent authentication. Please sign in again.',
        'requires-recent-login',
      );

    case 'operation-not-allowed':
      return const AuthException(
        'This sign-in method is temporarily unavailable.',
        'operation-not-allowed',
      );

    default:
      return UnknownException(
        error.message ?? 'Authentication error occurred.',
        error.code,
      );
  }
}

/// Maps [FirebaseFunctionsException] into typed domain [AppException].
AppException mapFirebaseFunctionsException(FirebaseFunctionsException error) {
  switch (error.code) {
    case 'unauthenticated':
      return const UnauthenticatedException();
    case 'permission-denied':
      return const PermissionException();
    case 'not-found':
      return const NotFoundException();
    case 'invalid-argument':
    case 'failed-precondition':
    case 'out-of-range':
      return ValidationException(
        error.message ?? 'Invalid arguments provided.',
        error.code,
      );
    case 'already-exists':
      return ValidationException(
        error.message ?? 'Resource already exists.',
        'already-exists',
      );
    case 'resource-exhausted':
      return ServerException(
        'Rate limit exceeded. Please wait a moment and try again.',
        'resource-exhausted',
      );
    case 'unavailable':
      return const NetworkException();
    case 'deadline-exceeded':
      return const NetworkException('Request timed out. Please try again.');
    default:
      return ServerException(
        error.message ?? 'A Cloud Function error occurred.',
        error.code,
      );
  }
}

/// Main error handler for repositories, notifiers, and services.
AppException handleException(Object error, [StackTrace? stack]) {
  // Record non-domain or critical crashes non-fatally
  if (error is! AppException) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    } catch (_) {
      // Ignored if Firebase is not yet initialized (e.g. in tests)
    }
  }

  if (error is FirebaseAuthException) {
    return mapFirebaseAuthException(error);
  }

  if (error is FirebaseFunctionsException) {
    return mapFirebaseFunctionsException(error);
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return const PermissionException();
      case 'unauthenticated':
        return const UnauthenticatedException();
      case 'not-found':
        return const NotFoundException();
      case 'unavailable':
        return const NetworkException();
      case 'deadline-exceeded':
        return const NetworkException('Request timed out. Please try again.');
      default:
        return ServerException(
          error.message ?? 'A Firebase service error occurred.',
          error.code,
        );
    }
  }

  if (error is AppException) {
    return error;
  }

  return UnknownException(error.toString());
}
