// lib/core/theme/app_text_styles.dart
// Named text styles that layer on top of Material 3 TextTheme.
// Use Theme.of(context).textTheme for most cases; these are for overrides.
import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  /// Job title on card
  static const TextStyle jobTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Company name sub-label
  static const TextStyle companyName = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Salary / meta badge
  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Section header above a list
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  /// Password strength label
  static const TextStyle strengthLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Error / helper text below inputs
  static const TextStyle helperText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}
