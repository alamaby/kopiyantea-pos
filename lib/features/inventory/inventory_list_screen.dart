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
import '../../l10n/generated/app_localizations.dart';
import '../settings/branch_selection_provider.dart';
import 'inventory_providers.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(selectedBranchProvider);
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: branchAsync.maybeWhen(
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.inventoryStock),
              if (b != null)
                Text(
                  b.name,
                  style: AppTypography.labelSm
                      .copyWith(color: context.colors.textSecondary),
                ),
            ],
          ),
          orElse: () => Text(l10n.inventoryStock),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_inventory',
        onPressed: () => context.push('/inventory/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.inventoryAddItem),
      ),
      body: branchAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: l10n.inventoryLoadBranchFailed,
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branch) {
          if (branch == null) {
            return AppEmptyState(
              title: l10n.inventoryNoBranchTitle,
              icon: Icons.store_outlined,
              message: l10n.inventoryNoBranchMessage,
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
    final l10n = AppL10n.of(context);

    return itemsAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => AppEmptyState(
        title: l10n.inventoryLoadStockFailed,
        icon: Icons.error_outline,
        message: e.toString(),
      ),
      data: (items) {
        if (items.isEmpty) {
          return AppEmptyState(
            title: l10n.inventoryEmptyTitle,
            icon: Icons.inventory_2_outlined,
            message: l10n.inventoryEmptyMessage,
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
    final l10n = AppL10n.of(context);
    final status = _stockStatus(l10n, item.cachedStock, item.minStock);

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => context.push('/inventory/${item.id}'),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
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
                      '${formatStock(item.cachedStock, item.unit)}  ·  ${l10n.inventoryMinimumShort(formatStock(item.minStock, item.unit))}',
                      style: AppTypography.bodySm
                          .copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.textTertiary,
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

_Status _stockStatus(AppL10n l10n, double current, double min) {
  if (current <= 0) {
    return _Status(
      label: l10n.inventoryOutOfStock,
      icon: Icons.error_outline,
      tone: AppBadgeTone.danger,
    );
  }
  if (current <= min) {
    return _Status(
      label: l10n.inventoryLowStock,
      icon: Icons.warning_amber_outlined,
      tone: AppBadgeTone.warning,
    );
  }
  return _Status(
    label: l10n.inventoryEnoughStock,
    icon: Icons.check_circle_outline,
    tone: AppBadgeTone.success,
  );
}
