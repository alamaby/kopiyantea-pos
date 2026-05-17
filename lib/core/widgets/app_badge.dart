import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum AppBadgeTone { info, success, warning, danger, neutral, accent }

/// Semantic badge. Color is never the sole signal — every tone enforces an icon
/// (color-blind safety, master prompt §6.7).
///
/// Backgrounds adapt per theme brightness: in light mode the tint surfaces are
/// pastels; in dark mode they're translucent overlays of the same hue. The
/// foreground (icon + text) keeps the brand colour so the badge is recognisable
/// across modes.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    required this.icon,
    super.key,
    this.tone = AppBadgeTone.neutral,
  });

  final String label;
  final IconData icon;
  final AppBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(tone, context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: AppRadius.radiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.labelXs.copyWith(color: palette.foreground),
          ),
        ],
      ),
    );
  }

  _BadgePalette _paletteFor(AppBadgeTone t, BuildContext ctx) {
    final dark = Theme.of(ctx).brightness == Brightness.dark;
    final pal = ctx.colors;
    return switch (t) {
      AppBadgeTone.info => _BadgePalette(
          background: dark
              ? AppColors.info.withValues(alpha: 0.22)
              : const Color(0xFFDBEAFE),
          foreground: dark ? const Color(0xFFBFDBFE) : AppColors.info,
        ),
      AppBadgeTone.success => _BadgePalette(
          background: dark
              ? AppColors.success.withValues(alpha: 0.22)
              : const Color(0xFFE0F2FE),
          foreground: dark ? const Color(0xFFBAE6FD) : AppColors.success,
        ),
      AppBadgeTone.warning => _BadgePalette(
          background: dark
              ? AppColors.warning.withValues(alpha: 0.22)
              : const Color(0xFFFEF3C7),
          foreground: dark ? const Color(0xFFFDE68A) : AppColors.warning,
        ),
      AppBadgeTone.danger => _BadgePalette(
          background: dark
              ? AppColors.danger.withValues(alpha: 0.22)
              : const Color(0xFFFEE2E2),
          foreground: dark ? const Color(0xFFFECACA) : AppColors.danger,
        ),
      AppBadgeTone.neutral => _BadgePalette(
          background: pal.surfaceAlt,
          foreground: pal.textSecondary,
        ),
      AppBadgeTone.accent => _BadgePalette(
          background: dark
              ? AppColors.accent.withValues(alpha: 0.22)
              : AppColors.accentSurface,
          foreground: dark ? const Color(0xFFFDBA74) : AppColors.accent,
        ),
    };
  }
}

class _BadgePalette {
  const _BadgePalette({required this.background, required this.foreground});
  final Color background;
  final Color foreground;
}
