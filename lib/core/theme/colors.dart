import 'package:flutter/material.dart';

/// Design system color tokens. See ADR-0013.
///
/// Rules:
/// - Never use a raw [Color] outside this file (lint: avoid_dynamic_calls + review).
/// - Semantic colors (success/warning/danger) MUST be paired with an icon in UI.
/// - Success is Sky-600, NOT green — color-blind safe under deuteranopia / protanopia.
abstract final class AppColors {
  AppColors._();

  // Primary — Teal
  static const Color primary = Color(0xFF0F766E); // Teal-700
  static const Color primaryLight = Color(0xFF5EEAD4); // Teal-300
  static const Color primaryDark = Color(0xFF134E4A); // Teal-900
  static const Color primarySurface = Color(0xFFCCFBF1); // Teal-100

  // Accent — Orange (CTAs, discount badges)
  static const Color accent = Color(0xFFEA580C); // Orange-600
  static const Color accentSurface = Color(0xFFFED7AA); // Orange-200

  // Semantic — always paired with icon in UI
  static const Color info = Color(0xFF2563EB); // Blue-600
  static const Color success = Color(0xFF0284C7); // Sky-600 (NOT green)
  static const Color warning = Color(0xFFD97706); // Amber-600
  static const Color danger = Color(0xFFDC2626); // Red-600

  // Light mode neutrals — Stone
  static const Color bg = Color(0xFFFAFAF9); // Stone-50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF5F5F4); // Stone-100
  static const Color border = Color(0xFFE7E5E4); // Stone-200
  static const Color textPrimary = Color(0xFF1C1917); // Stone-900
  static const Color textSecondary = Color(0xFF57534E); // Stone-600
  static const Color textTertiary = Color(0xFFA8A29E); // Stone-400
  static const Color disabled = Color(0xFFD6D3D1); // Stone-300

  // Dark mode neutrals
  static const Color bgDark = Color(0xFF1C1917); // Stone-900
  static const Color surfaceDark = Color(0xFF292524); // Stone-800
  static const Color surfaceAltDark = Color(0xFF44403C); // Stone-700
  static const Color borderDark = Color(0xFF57534E); // Stone-600
  static const Color textPrimaryDark = Color(0xFFFAFAF9);
  static const Color textSecondaryDark = Color(0xFFD6D3D1);
  static const Color textTertiaryDark = Color(0xFFA8A29E);
}
