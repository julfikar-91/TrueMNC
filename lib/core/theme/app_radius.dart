// lib/core/theme/app_radius.dart
// Border-radius tokens — single source of truth.
import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double none   = 0.0;
  static const double xs     = 4.0;
  static const double sm     = 8.0;
  static const double md     = 12.0;
  static const double lg     = 16.0;
  static const double xl     = 24.0;
  static const double full   = 999.0; // pill / chip

  // BorderRadius shorthands
  static BorderRadius get cardRadius  => BorderRadius.circular(md);
  static BorderRadius get buttonRadius => BorderRadius.circular(sm);
  static BorderRadius get chipRadius  => BorderRadius.circular(full);
  static BorderRadius get inputRadius => BorderRadius.circular(sm);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(xl));
}
