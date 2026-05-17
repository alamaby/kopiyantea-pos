import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'inventory_providers.dart';

class InventoryDetailScreen extends ConsumerWidget {
  const InventoryDetailScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(inventoryItemProvider(itemId));

    return Scaffold(
      appBar: AppBar(
        title: itemAsync.maybeWhen(
          data: (item) => Text(item?.name ?? 'Detail Stok'),
          orElse: () => const Text('Detail Stok'),
        ),
      ),
      body: itemAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat item',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (item) {
          if (item == null) {
            return const AppEmptyState(
              title: 'Item tidak ditemukan',
              icon: Icons.search_off_outlined,
            );
          }
          return _DetailBody(item: item);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.item});

  final InventoryItemRow item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(inventoryMovementsProvider(item.id));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _SummaryCard(item: item),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'RIWAYAT PERGERAKAN',
            style: AppTypography.labelSm.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        movementsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: AppLoadingIndicator()),
          ),
          error: (e, _) => Text(
            'Gagal memuat riwayat: $e',
            style: AppTypography.bodySm.copyWith(color: AppColors.danger),
          ),
          data: (movements) {
            if (movements.isEmpty) {
              return _EmptyMovements();
            }
            return Column(
              children: [
                for (final m in movements) ...[
                  _MovementTile(movement: m, unit: item.unit),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final InventoryItemRow item;

  @override
  Widget build(BuildContext context) {
    final low = item.cachedStock <= item.minStock;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STOK SAAT INI',
            style: AppTypography.labelSm.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatStock(item.cachedStock, item.unit),
            style: AppTypography.displayMd.copyWith(
              color: low ? AppColors.warning : AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Row(label: 'Minimum', value: formatStock(item.minStock, item.unit)),
          _Row(
            label: 'Harga modal',
            value:
                '${formatRupiah(item.costPerUnit)}/${stockUnitLabel(item.unit)}',
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.unit});

  final InventoryMovementRow movement;
  final StockUnit unit;

  @override
  Widget build(BuildContext context) {
    final isPositive = movement.deltaSigned > 0;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final prefix = isPositive ? '+' : '';
    final qty = formatStock(movement.deltaSigned.abs(), unit);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Icon(
              _iconFor(movement.movementType),
              size: 18,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movementTypeLabel(movement.movementType),
                  style: AppTypography.titleMd,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatDateTime(movement.createdAt),
                  style: AppTypography.bodySm
                      .copyWith(color: context.colors.textSecondary),
                ),
                if (movement.notes != null && movement.notes!.isNotEmpty)
                  Text(
                    movement.notes!,
                    style: AppTypography.bodySm
                        .copyWith(color: context.colors.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            '$prefix${isPositive ? "" : "-"}$qty',
            style: AppTypography.titleMd.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(MovementType type) => switch (type) {
        MovementType.purchase => Icons.add_shopping_cart_outlined,
        MovementType.sale => Icons.point_of_sale_outlined,
        MovementType.adjustment => Icons.tune_outlined,
        MovementType.waste => Icons.delete_outline,
        MovementType.transfer => Icons.swap_horiz_outlined,
      };
}

class _EmptyMovements extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: AppRadius.radiusLg,
      ),
      child: Center(
        child: Text(
          'Belum ada pergerakan stok',
          style:
              AppTypography.bodySm.copyWith(color: context.colors.textSecondary),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style:
                AppTypography.bodyMd.copyWith(color: context.colors.textSecondary),
          ),
          const Spacer(),
          Text(value, style: AppTypography.bodyMd),
        ],
      ),
    );
  }
}
