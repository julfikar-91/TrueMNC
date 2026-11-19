// lib/core/errors/app_exception.dart
import 'package:equatable/equatable.dart';

/// Base class for all domain-level exceptions in TrueMNC.
sealed class AppException extends Equatable implements Exception {
  const AppException(this.message, [this.code]);
  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => '$runtimeType(code: $code): $message';
}

/// Thrown when authentication fails.
/// Uses generic message for wrong credentials to prevent account enumeration.
class AuthException extends AppException {
  const AuthException(super.message, [super.code]);

  /// Factory for anti-enumeration invalid credentials
  factory AuthException.invalidCredentials() => const AuthException(
        'Invalid email or password. Please check your credentials and try again.',
        'invalid-credentials',
      );

  factory AuthException.accountDisabled() => const AuthException(
        'This account has been disabled. Please contact support.',
        'user-disabled',
      );

  factory AuthException.tooManyRequests() => const AuthException(
        'Too many attempts. Please wait a moment before trying again.',
        'too-many-requests',
      );

  factory AuthException.emailAlreadyInUse() => const DuplicateEmailException();
}

/// Specialized exception for duplicate email on signup with friendly links hint
final class DuplicateEmailException extends AuthException {
  const DuplicateEmailException([
    super.message =
        'An account with this email already exists. Please log in, or reset your password if you forgot it.',
    super.code = 'email-already-in-use',
  ]);
}

/// Thrown when user is not authenticated for an operation requiring login.
final class UnauthenticatedException extends AppException {
  const UnauthenticatedException([
    super.message = 'You must be signed in to perform this action.',
    super.code = 'unauthenticated',
  ]);
}

/// Thrown when the user lacks permission for an action (e.g. role check).
final class PermissionException extends AppException {
  const PermissionException([
    super.message = 'You do not have permission to perform this action.',
    super.code = 'permission-denied',
  ]);
}

/// Thrown when a network or offline operation fails.
final class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network error. Please check your internet connection.',
    super.code = 'network-error',
  ]);
}

/// Thrown when a requested resource does not exist.
final class NotFoundException extends AppException {
  const NotFoundException([
    super.message = 'The requested item was not found.',
    super.code = 'not-found',
  ]);
}

/// Thrown when input validation fails.
final class ValidationException extends AppException {
  const ValidationException(super.message, [super.code = 'validation-error']);
}

/// Thrown for internal server or Cloud Function failures.
final class ServerException extends AppException {
  const ServerException([
    super.message = 'Server encountered an error. Please try again later.',
    super.code = 'server-error',
  ]);
}

/// Fallback for unexpected errors.
final class UnknownException extends AppException {
  const UnknownException([
    super.message = 'An unexpected error occurred. Please try again.',
    super.code = 'unknown',
  ]);
}
