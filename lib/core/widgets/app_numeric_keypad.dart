import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// POS-optimized numeric keypad. Buttons sized at 64pt (master prompt §6.5).
class AppNumericKeypad extends StatelessWidget {
  const AppNumericKeypad({
    required this.onKey,
    required this.onBackspace,
    super.key,
    this.onConfirm,
    this.confirmLabel,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback? onConfirm;
  final String? confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _Row(keys: row, onKey: onKey),
        Row(
          children: [
            _KeyButton(label: '000', onTap: () => onKey('000')),
            _KeyButton(label: '0', onTap: () => onKey('0')),
            _KeyButton(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
              haptic: HapticFeedback.lightImpact,
            ),
          ],
        ),
        if (onConfirm != null && confirmLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              height: AppTouchTarget.primaryTablet,
              child: Material(
                color: AppColors.primary,
                borderRadius: AppRadius.radiusMd,
                child: InkWell(
                  onTap: onConfirm,
                  borderRadius: AppRadius.radiusMd,
                  child: Center(
                    child: Text(
                      confirmLabel!,
                      style: AppTypography.titleMd.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.keys, required this.onKey});

  final List<String> keys;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys
          .map((k) => _KeyButton(label: k, onTap: () => onKey(k)))
          .toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    this.label,
    this.icon,
    required this.onTap,
    this.haptic,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final Future<void> Function()? haptic;

  @override
  Widget build(BuildContext context) {
    final pal = context.colors;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: SizedBox(
          height: AppTouchTarget.numericKeypad,
          child: Material(
            color: pal.surface,
            borderRadius: AppRadius.radiusMd,
            child: InkWell(
              borderRadius: AppRadius.radiusMd,
              onTap: () {
                (haptic ?? HapticFeedback.selectionClick).call();
                onTap();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: pal.border),
                ),
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(icon, color: pal.textPrimary)
                    : Text(label!, style: AppTypography.headlineLg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
