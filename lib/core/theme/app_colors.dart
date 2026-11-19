// lib/core/theme/app_colors.dart
// Design token colours — referenced by ThemeData only; never hardcoded in widgets.
import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand seeds ───────────────────────────────────────────────────────────
  static const Color primarySeed   = Color(0xFF0057B8); // corporate blue
  static const Color secondarySeed = Color(0xFF00897B); // teal accent
  static const Color errorSeed     = Color(0xFFB3261E); // M3 error red

  // ── Neutral palette (used for custom surfaces) ────────────────────────────
  static const Color neutralLight  = Color(0xFFF6F8FC);
  static const Color neutralDark   = Color(0xFF1A1C1E);

  // ── Status / semantic ─────────────────────────────────────────────────────
  static const Color success       = Color(0xFF2E7D32);
  static const Color warning       = Color(0xFFF57C00);
  static const Color info          = Color(0xFF0277BD);

  // ── Password strength ─────────────────────────────────────────────────────
  static const Color strengthWeak   = Color(0xFFD32F2F);
  static const Color strengthMedium = Color(0xFFF57C00);
  static const Color strengthStrong = Color(0xFF2E7D32);

  // ── Skeleton shimmer ──────────────────────────────────────────────────────
  static const Color shimmerBase    = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  static const Color shimmerBaseDark    = Color(0xFF2C2C2C);
  static const Color shimmerHighlightDark = Color(0xFF3D3D3D);
}
