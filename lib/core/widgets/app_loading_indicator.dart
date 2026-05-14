import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';

enum AppLoadingVariant { spinner, shimmer }

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.variant = AppLoadingVariant.spinner,
    this.size = 24,
  });

  final AppLoadingVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppLoadingVariant.spinner => SizedBox(
          height: size,
          width: size,
          child: const CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      AppLoadingVariant.shimmer => const _ShimmerBlock(),
    };
  }
}

class _ShimmerBlock extends StatefulWidget {
  const _ShimmerBlock();

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          height: AppSpacing.xl,
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusMd,
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: const [
                AppColors.surfaceAlt,
                AppColors.border,
                AppColors.surfaceAlt,
              ],
            ),
          ),
        );
      },
    );
  }
}
