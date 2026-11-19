// lib/core/theme/app_spacing.dart
// Spacing tokens (8-pt grid). Use these instead of magic numbers.
abstract final class AppSpacing {
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;
  static const double xxxl = 64.0;

  /// Standard page horizontal padding.
  static const double pagePadding = md;

  /// Standard card internal padding.
  static const double cardPadding = md;

  /// Minimum interactive touch target (WCAG / Material guidance).
  static const double minTouchTarget = 48.0;
}
