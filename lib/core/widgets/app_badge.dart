import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum AppBadgeTone { info, success, warning, danger, neutral, accent }

/// Semantic badge. Color is never the sole signal — every tone enforces an icon
/// (color-blind safety, master prompt §6.7).
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
    final palette = _paletteFor(tone);
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

  _BadgePalette _paletteFor(AppBadgeTone t) {
    return switch (t) {
      AppBadgeTone.info =>
        const _BadgePalette(background: Color(0xFFDBEAFE), foreground: AppColors.info),
      AppBadgeTone.success =>
        const _BadgePalette(background: Color(0xFFE0F2FE), foreground: AppColors.success),
      AppBadgeTone.warning =>
        const _BadgePalette(background: Color(0xFFFEF3C7), foreground: AppColors.warning),
      AppBadgeTone.danger =>
        const _BadgePalette(background: Color(0xFFFEE2E2), foreground: AppColors.danger),
      AppBadgeTone.neutral =>
        const _BadgePalette(background: AppColors.surfaceAlt, foreground: AppColors.textSecondary),
      AppBadgeTone.accent =>
        const _BadgePalette(background: AppColors.accentSurface, foreground: AppColors.accent),
    };
  }
}

class _BadgePalette {
  const _BadgePalette({required this.background, required this.foreground});
  final Color background;
  final Color foreground;
}
