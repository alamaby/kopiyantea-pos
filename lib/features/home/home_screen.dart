import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/generated/app_localizations.dart';
import '../reports/widgets/today_quick_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [
          TodayQuickBadge(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.homeWelcome, style: AppTypography.displayMd),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.homeSubtitle,
            style: AppTypography.bodyMd
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.homeShortcuts, style: AppTypography.headlineMd),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in [
                      (l10n.navPos, '/pos'),
                      (l10n.navProducts, '/products'),
                      (l10n.navInventory, '/more/inventory'),
                      (l10n.navTransactions, '/transactions'),
                      (l10n.navCustomers, '/more/customers'),
                      (l10n.navReports, '/reports'),
                      (l10n.navSettings, '/more/settings'),
                    ])
                      AppButton(
                        label: entry.$1,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.compact,
                        onPressed: () => context.push(entry.$2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
