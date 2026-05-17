import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';

enum AppCardVariant { raised, flat, interactive }

/// Card primitive. Default variant is bordered (flat) — Material-3 friendly.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.variant = AppCardVariant.raised,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.colors;
    final decoration = BoxDecoration(
      color: pal.surface,
      borderRadius: AppRadius.radiusLg,
      border: Border.all(color: pal.border),
      boxShadow: variant == AppCardVariant.raised
          ? const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ]
          : null,
    );

    final content = Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );

    if (variant == AppCardVariant.interactive && onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLg,
          child: content,
        ),
      );
    }
    return content;
  }
}
