import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

enum AppButtonSize { standard, primary, compact }

/// Primary button primitive. See master prompt §6.6.
///
/// - Disables itself while [isLoading]; submit-prevention behavior baked in.
/// - Touch target ≥ 48 (standard) / 56 (primary) / 44 (compact, min).
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.standard,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final pal = context.colors;
    final disabled = onPressed == null || isLoading;
    final colors = _colorsFor(variant, pal);
    final height = switch (size) {
      AppButtonSize.compact => AppTouchTarget.minimum,
      AppButtonSize.standard => AppTouchTarget.standard,
      AppButtonSize.primary => AppTouchTarget.primaryTablet,
    };

    final child = isLoading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: colors.foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style:
                      AppTypography.titleMd.copyWith(color: colors.foreground),
                ),
              ),
            ],
          );

    final button = Material(
      color: disabled ? pal.disabled : colors.background,
      borderRadius: AppRadius.radiusMd,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: AppRadius.radiusMd,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusMd,
            border: variant == AppButtonVariant.ghost
                ? Border.all(color: pal.border)
                : null,
          ),
          child: child,
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  _ButtonColors _colorsFor(AppButtonVariant v, AppPalette pal) {
    return switch (v) {
      AppButtonVariant.primary => const _ButtonColors(
          background: AppColors.primary, foreground: Colors.white),
      AppButtonVariant.secondary => const _ButtonColors(
          background: AppColors.primarySurface,
          foreground: AppColors.primaryDark),
      AppButtonVariant.danger => const _ButtonColors(
          background: AppColors.danger, foreground: Colors.white),
      AppButtonVariant.ghost => _ButtonColors(
          background: Colors.transparent, foreground: pal.textPrimary),
    };
  }
}

class _ButtonColors {
  const _ButtonColors({required this.background, required this.foreground});
  final Color background;
  final Color foreground;
}
