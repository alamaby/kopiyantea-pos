import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../settings/branch_selection_provider.dart';
import 'inventory_providers.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(selectedBranchProvider);

    return Scaffold(
      appBar: AppBar(
        title: branchAsync.maybeWhen(
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Stok'),
              if (b != null)
                Text(
                  b.name,
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
          orElse: () => const Text('Stok'),
        ),
      ),
      body: branchAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat cabang',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branch) {
          if (branch == null) {
            return const AppEmptyState(
              title: 'Belum memilih cabang',
              icon: Icons.store_outlined,
              message: 'Pilih cabang aktif di Pengaturan.',
            );
          }
          return _InventoryList(branchId: branch.id);
        },
      ),
    );
  }
}

class _InventoryList extends ConsumerWidget {
  const _InventoryList({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(branchInventoryProvider(branchId));

    return itemsAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => AppEmptyState(
        title: 'Gagal memuat stok',
        icon: Icons.error_outline,
        message: e.toString(),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const AppEmptyState(
            title: 'Belum ada item stok',
            icon: Icons.inventory_2_outlined,
            message: 'Tambahkan item dari menu manajemen.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _InventoryTile(item: items[i]),
        );
      },
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.item});

  final InventoryItemRow item;

  @override
  Widget build(BuildContext context) {
    final status = _stockStatus(item.cachedStock, item.minStock);

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => context.push('/inventory/${item.id}'),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTypography.titleMd,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppBadge(
                          label: status.label,
                          icon: status.icon,
                          tone: status.tone,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${formatStock(item.cachedStock, item.unit)}  ·  min ${formatStock(item.minStock, item.unit)}',
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stock status ──────────────────────────────────────────────────────────────

class _Status {
  const _Status({required this.label, required this.icon, required this.tone});
  final String label;
  final IconData icon;
  final AppBadgeTone tone;
}

_Status _stockStatus(double current, double min) {
  if (current <= 0) {
    return const _Status(
      label: 'Habis',
      icon: Icons.error_outline,
      tone: AppBadgeTone.danger,
    );
  }
  if (current <= min) {
    return const _Status(
      label: 'Menipis',
      icon: Icons.warning_amber_outlined,
      tone: AppBadgeTone.warning,
    );
  }
  return const _Status(
    label: 'Cukup',
    icon: Icons.check_circle_outline,
    tone: AppBadgeTone.success,
  );
}
