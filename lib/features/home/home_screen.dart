import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../reports/widgets/today_quick_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KopiyanteaPOS'),
        actions: const [
          TodayQuickBadge(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Selamat datang', style: AppTypography.displayMd),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Phase 1 — fondasi aplikasi siap. Fitur dibangun pada Phase 2–4.',
            style: AppTypography.bodyMd.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Navigasi sementara', style: AppTypography.headlineMd),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in const [
                      ('Kasir', '/pos'),
                      ('Menu', '/products'),
                      ('Stok', '/inventory'),
                      ('Transaksi', '/transactions'),
                      ('Pelanggan', '/customers'),
                      ('Laporan', '/reports'),
                      ('Pengaturan', '/settings'),
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
