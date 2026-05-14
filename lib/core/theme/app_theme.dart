import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';
import 'spacing.dart';
import 'typography.dart';

/// Composes [ThemeData] for light and dark modes from the design tokens.
///
/// Feature code consumes the theme via `Theme.of(context)` and the token
/// modules ([AppColors], [AppTypography], [AppSpacing], [AppRadius]) directly.
/// Do NOT introduce raw [Color] or [TextStyle] values in feature widgets.
abstract final class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(_LightTokens());
  static ThemeData dark() => _build(_DarkTokens());

  static ThemeData _build(_ThemeTokens t) {
    final textTheme = TextTheme(
      displayLarge: AppTypography.displayLg.copyWith(color: t.textPrimary),
      displayMedium: AppTypography.displayMd.copyWith(color: t.textPrimary),
      headlineLarge: AppTypography.headlineLg.copyWith(color: t.textPrimary),
      headlineMedium: AppTypography.headlineMd.copyWith(color: t.textPrimary),
      titleMedium: AppTypography.titleMd.copyWith(color: t.textPrimary),
      bodyLarge: AppTypography.bodyLg.copyWith(color: t.textPrimary),
      bodyMedium: AppTypography.bodyMd.copyWith(color: t.textPrimary),
      bodySmall: AppTypography.bodySm.copyWith(color: t.textSecondary),
      labelMedium: AppTypography.labelSm.copyWith(color: t.textSecondary),
      labelSmall: AppTypography.labelXs.copyWith(color: t.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme(
        brightness: t.brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primarySurface,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.accentSurface,
        onSecondaryContainer: AppColors.accent,
        error: AppColors.danger,
        onError: Colors.white,
        surface: t.surface,
        onSurface: t.textPrimary,
        surfaceContainerHighest: t.surfaceAlt,
        outline: t.border,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineMd.copyWith(color: t.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: BorderSide(color: t.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: t.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.textPrimary,
        contentTextStyle: AppTypography.bodyMd.copyWith(color: t.surface),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
      ),
    );
  }
}

abstract class _ThemeTokens {
  Brightness get brightness;
  Color get bg;
  Color get surface;
  Color get surfaceAlt;
  Color get border;
  Color get textPrimary;
  Color get textSecondary;
}

class _LightTokens implements _ThemeTokens {
  @override
  Brightness get brightness => Brightness.light;
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
}

class _DarkTokens implements _ThemeTokens {
  @override
  Brightness get brightness => Brightness.dark;
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
}
