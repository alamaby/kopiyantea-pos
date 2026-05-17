import 'package:flutter/material.dart';

/// Design system color tokens. See ADR-0013.
///
/// Two layers:
/// - **Static brand colors** (e.g. [primary], [accent], [danger]) — same in
///   both light and dark mode. Reference them directly: `AppColors.primary`.
/// - **Theme-adaptive surfaces & text** (e.g. surface, textPrimary) — read
///   via the [AppPalette] returned by `context.colors`.
///
/// Rules:
/// - Never use a raw [Color] outside this file.
/// - Semantic colors (success/warning/danger) MUST be paired with an icon in UI.
/// - Success is Sky-600, NOT green — color-blind safe under deuteranopia / protanopia.
abstract final class AppColors {
  AppColors._();

  // ── Brand (mode-invariant) ──────────────────────────────────────────────────

  static const Color primary = Color(0xFF0F766E); // Teal-700
  static const Color primaryLight = Color(0xFF5EEAD4); // Teal-300
  static const Color primaryDark = Color(0xFF134E4A); // Teal-900
  static const Color primarySurface = Color(0xFFCCFBF1); // Teal-100

  static const Color accent = Color(0xFFEA580C); // Orange-600
  static const Color accentSurface = Color(0xFFFED7AA); // Orange-200

  static const Color info = Color(0xFF2563EB); // Blue-600
  static const Color success = Color(0xFF0284C7); // Sky-600 (NOT green)
  static const Color warning = Color(0xFFD97706); // Amber-600
  static const Color danger = Color(0xFFDC2626); // Red-600

  // ── Light mode neutrals — Stone ─────────────────────────────────────────────

  static const Color bg = Color(0xFFFAFAF9); // Stone-50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF5F5F4); // Stone-100
  static const Color border = Color(0xFFE7E5E4); // Stone-200
  static const Color textPrimary = Color(0xFF1C1917); // Stone-900
  static const Color textSecondary = Color(0xFF57534E); // Stone-600
  static const Color textTertiary = Color(0xFFA8A29E); // Stone-400
  static const Color disabled = Color(0xFFD6D3D1); // Stone-300

  // ── Dark mode neutrals ──────────────────────────────────────────────────────

  static const Color bgDark = Color(0xFF1C1917); // Stone-900
  static const Color surfaceDark = Color(0xFF292524); // Stone-800
  static const Color surfaceAltDark = Color(0xFF44403C); // Stone-700
  static const Color borderDark = Color(0xFF57534E); // Stone-600
  static const Color textPrimaryDark = Color(0xFFFAFAF9);
  static const Color textSecondaryDark = Color(0xFFD6D3D1);
  static const Color textTertiaryDark = Color(0xFFA8A29E);
  static const Color disabledDark = Color(0xFF57534E); // Stone-600
}

// ── Theme-adaptive palette ────────────────────────────────────────────────────

/// Theme-adaptive surfaces & text. Resolve via `context.colors`.
abstract interface class AppPalette {
  Color get bg;
  Color get surface;
  Color get surfaceAlt;
  Color get border;
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get disabled;
}

class _LightPalette implements AppPalette {
  const _LightPalette();
  @override
  Color get bg => AppColors.bg;
  @override
  Color get surface => AppColors.surface;
  @override
  Color get surfaceAlt => AppColors.surfaceAlt;
  @override
  Color get border => AppColors.border;
  @override
  Color get textPrimary => AppColors.textPrimary;
  @override
  Color get textSecondary => AppColors.textSecondary;
  @override
  Color get textTertiary => AppColors.textTertiary;
  @override
  Color get disabled => AppColors.disabled;
}

class _DarkPalette implements AppPalette {
  const _DarkPalette();
  @override
  Color get bg => AppColors.bgDark;
  @override
  Color get surface => AppColors.surfaceDark;
  @override
  Color get surfaceAlt => AppColors.surfaceAltDark;
  @override
  Color get border => AppColors.borderDark;
  @override
  Color get textPrimary => AppColors.textPrimaryDark;
  @override
  Color get textSecondary => AppColors.textSecondaryDark;
  @override
  Color get textTertiary => AppColors.textTertiaryDark;
  @override
  Color get disabled => AppColors.disabledDark;
}

const AppPalette _light = _LightPalette();
const AppPalette _dark = _DarkPalette();

extension AppPaletteContext on BuildContext {
  /// Theme-adaptive palette. Reads `Theme.of(this).brightness` and returns
  /// the matching [AppPalette]. Use this instead of touching
  /// `AppColors.surface` / `AppColors.textPrimary` etc. directly inside widgets.
  AppPalette get colors =>
      Theme.of(this).brightness == Brightness.dark ? _dark : _light;
}
