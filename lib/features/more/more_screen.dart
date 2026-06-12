import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../l10n/generated/app_localizations.dart';

/// "Lainnya" hub — entry point for secondary destinations (Pelanggan,
/// Stok, Pengaturan). Kept off the primary nav to avoid > 5 BottomNav
/// items on mobile.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  List<_MoreItem> _items(BuildContext context) {
    final l10n = AppL10n.of(context);
    return [
      _MoreItem(
        label: l10n.navCustomers,
        icon: Icons.people_outline,
        route: '/more/customers',
      ),
      _MoreItem(
        label: l10n.navInventory,
        icon: Icons.inventory_2_outlined,
        route: '/more/inventory',
      ),
      _MoreItem(
        label: l10n.navShiftClosing,
        icon: Icons.point_of_sale_outlined,
        route: '/more/reports/closing',
      ),
      _MoreItem(
        label: l10n.navSettings,
        icon: Icons.settings_outlined,
        route: '/more/settings',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(context);
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _MoreTile(item: items[i]),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item});

  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => context.push(item.route),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              Icon(item.icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(item.label, style: AppTypography.titleMd),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
