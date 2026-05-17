import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';

/// "Lainnya" hub — entry point for secondary destinations (Pelanggan,
/// Laporan, Pengaturan). Kept off the primary nav to avoid > 5 BottomNav
/// items on mobile.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _items = <_MoreItem>[
    _MoreItem(
      label: 'Pelanggan',
      icon: Icons.people_outline,
      route: '/more/customers',
    ),
    _MoreItem(
      label: 'Laporan',
      icon: Icons.bar_chart_outlined,
      route: '/more/reports',
    ),
    _MoreItem(
      label: 'Pengaturan',
      icon: Icons.settings_outlined,
      route: '/more/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _MoreTile(item: _items[i]),
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
