import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../cart_provider.dart';
import '../held_order_service.dart';

/// FEAT-009 — bottom sheet listing parked carts for the active branch.
/// Tap a row to restore it into the cart; swipe / tap delete to discard.
class HeldOrdersSheet extends ConsumerWidget {
  const HeldOrdersSheet({required this.branchId, super.key});
  final String branchId;

  static Future<void> show(BuildContext context, String branchId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (_) => HeldOrdersSheet(branchId: branchId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final heldAsync = ref.watch(heldOrdersForBranchProvider(branchId));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text(l10n.cartHoldOrder, style: AppTypography.displayMd),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: heldAsync.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => AppEmptyState(
                title: l10n.heldOrdersLoadFailed,
                icon: Icons.error_outline,
                message: e.toString(),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return AppEmptyState(
                    title: l10n.heldOrdersEmptyTitle,
                    icon: Icons.pause_circle_outline,
                    message: l10n.heldOrdersEmptyMessage,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _HeldOrderTile(row: rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeldOrderTile extends ConsumerWidget {
  const _HeldOrderTile({required this.row});
  final HeldOrderRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final previewAsync = ref.watch(heldOrderPreviewProvider(row));
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _restore(context, ref),
          borderRadius: AppRadius.radiusLg,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.accentSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause_circle_outline,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.label,
                              style: AppTypography.titleMd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            previewAsync.maybeWhen(
                              data: (preview) => formatRupiah(preview.total),
                              orElse: () => '...',
                            ),
                            style: AppTypography.titleMd.copyWith(
                              color: AppColors.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        previewAsync.maybeWhen(
                          data: (preview) => preview.firstItemName,
                          orElse: () => l10n.heldOrdersLoadingItem,
                        ),
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatDateTime(row.createdAt),
                        style: AppTypography.labelSm.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: context.colors.textTertiary),
                  tooltip: l10n.heldOrdersDeleteTooltip,
                  onPressed: () => _confirmDiscard(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartNotifierProvider);
    final notifier = ref.read(cartNotifierProvider.notifier);
    final svc = ref.read(heldOrderServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    // Confirm overwrite if the cart already has items.
    if (cart.items.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppL10n.of(ctx).heldOrdersReplaceCartTitle),
          content: Text(AppL10n.of(ctx).heldOrdersReplaceCartMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppL10n.of(ctx).actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppL10n.of(ctx).heldOrdersReplaceAction),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final restored = await svc.restore(row);
    if (restored == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).heldOrdersBranchMissing)),
      );
      return;
    }
    notifier.restoreState(restored);
    ref.read(activeHeldOrderIdProvider.notifier).state = row.id;
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppL10n.of(context).heldOrdersRestored(row.label)),
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppL10n.of(ctx).heldOrdersDeleteTitle),
        content: Text(AppL10n.of(ctx).heldOrdersDeleteMessage(row.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppL10n.of(ctx).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(AppL10n.of(ctx).actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(heldOrderServiceProvider).discard(row.id);
  }
}

/// AppBar action — icon button with reactive count badge. Tap opens
/// [HeldOrdersSheet].
class HeldOrdersAction extends ConsumerWidget {
  const HeldOrdersAction({required this.branchId, super.key});
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(heldOrdersCountProvider(branchId));
    final count = countAsync.maybeWhen(data: (c) => c, orElse: () => 0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.pause_circle_outline),
          tooltip: AppL10n.of(context).heldOrdersTooltip,
          onPressed: () => HeldOrdersSheet.show(context, branchId),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                '$count',
                style: AppTypography.labelXs.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
