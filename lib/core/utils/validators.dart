// lib/core/utils/validators.dart

/// Form field validators for TrueMNC.
/// Each validator returns `null` if valid, or a user-facing error message string.
abstract final class Validators {
  // RFC 5322 simplified standard email regex
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  // Name: letters, spaces, hyphens, apostrophes (at least 2 characters)
  static final RegExp _nameRegExp = RegExp(
    r"^[a-zA-ZÀ-ÿ]+(?:[\s'-][a-zA-ZÀ-ÿ]+)*$",
  );

  /// Validates required field.
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates email address format.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password against TrueMNC security policy:
  /// - Minimum 8 characters
  /// - At least 1 letter (uppercase or lowercase)
  /// - At least 1 number
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'Password must contain at least one letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must contain at least one digit';
    }
    return null;
  }

  /// Validates password confirmation matches original password.
  static String? confirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates full or display name:
  /// - Minimum 2 characters, maximum 60
  /// - Only letters, spaces, hyphens, and apostrophes
  static String? name(String? value, [String fieldName = 'Name']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    if (trimmed.length > 60) {
      return '$fieldName cannot exceed 60 characters';
    }
    if (!_nameRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid name (letters only)';
    }
    return null;
  }

  /// Validates phone number (optional or min 10 digits).
  static String? phone(String? value, {bool isOptional = true}) {
    if (value == null || value.trim().isEmpty) {
      return isOptional ? null : 'Phone number is required';
    }
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Please enter a valid 10-15 digit phone number';
    }
    return null;
  }
}
