import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/pricing/pricing.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../customers/customer_picker_sheet.dart';
import '../../modifiers/modifier_providers.dart';
import '../cart_provider.dart';
import '../cart_state.dart';
import '../held_order_service.dart';
import '../print_receipt_use_case.dart';
import '../share_receipt_use_case.dart';
import 'checkout_sheet.dart';
import 'option_picker_sheet.dart';

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  bool _isSharingBill = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cartState = ref.watch(cartNotifierProvider);
    final notifier = ref.read(cartNotifierProvider.notifier);

    if (cartState.items.isEmpty) {
      return AppEmptyState(
        title: l10n.cartEmptyTitle,
        icon: Icons.shopping_cart_outlined,
        message: l10n.cartEmptyMessage,
      );
    }

    final totals = notifier.totals;

    return Column(
      children: [
        _Header(
          itemCount: notifier.itemCount,
          onClear: () => _confirmClear(context, notifier),
        ),
        const Divider(height: 1),
        _CustomerSection(
          customer: cartState.customer,
          onPick: () async {
            final result = await CustomerPickerSheet.show(context);
            if (result != null) {
              notifier.setCustomer(result.customer);
            }
          },
          onClear: () => notifier.setCustomer(null),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: cartState.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _CartItemTile(
              index: i,
              item: cartState.items[i],
              notifier: notifier,
            ),
          ),
        ),
        const Divider(height: 1),
        _CartTotalsView(
          totals: totals,
          subtotal: notifier.subtotal,
          discountAmount: cartState.manualDiscountAmount,
          taxLabel: cartState.branch?.taxLabel ?? 'PB1',
          branchSelected: cartState.branch != null,
          onEditDiscount: () =>
              _editDiscount(context, notifier, cartState.manualDiscountAmount),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                AppButton(
                  label: totals == null
                      ? l10n.posCheckout
                      : l10n.cartPayAmount(formatRupiah(totals.total)),
                  onPressed: totals != null && totals.total > 0
                      ? () => _openCheckout(context)
                      : null,
                  size: AppButtonSize.primary,
                  fullWidth: true,
                  icon: Icons.payment_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: l10n.cartPrintBill,
                        icon: Icons.receipt_long_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: totals == null
                            ? null
                            : () => _printBill(context, ref, cartState, totals),
                        fullWidth: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _ShareBillButton(
                      isLoading: _isSharingBill,
                      onPressed: totals == null || _isSharingBill
                          ? null
                          : () => _shareBill(context, cartState, totals),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: l10n.cartHoldOrder,
                        icon: Icons.pause_circle_outline,
                        variant: AppButtonVariant.secondary,
                        onPressed: cartState.branch == null
                            ? null
                            : () => _holdOrder(context, ref, cartState),
                        fullWidth: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareBill(
    BuildContext context,
    CartState cartState,
    TotalsResult totals,
  ) async {
    setState(() => _isSharingBill = true);
    var shared = false;
    try {
      shared =
          await ref.read(shareReceiptUseCaseProvider).shareBillReceiptImage(
                cart: cartState,
                totals: totals,
              );
    } catch (_) {
      shared = false;
    }
    if (!mounted) return;
    setState(() => _isSharingBill = false);

    if (!shared) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).cartShareBillFailed)),
      );
    }
  }

  Future<void> _printBill(
    BuildContext context,
    WidgetRef ref,
    CartState cartState,
    TotalsResult totals,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final result = await ref.read(printReceiptUseCaseProvider).printBill(
          cart: cartState,
          totals: totals,
        );
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          switch (result) {
            Ok() => l10n.cartBillSentToPrinter,
            Err(:final error) =>
              l10n.cartBillPrintFailed(_printerErrorLabel(l10n, error)),
          },
        ),
      ),
    );
  }

  String _printerErrorLabel(AppL10n l10n, PrinterError error) =>
      switch (error) {
        PrinterError.notConnected => l10n.cartPrinterNotConnected,
        PrinterError.deviceNotFound => l10n.cartPrinterNotFound,
        PrinterError.permissionDenied => l10n.cartBluetoothPermissionDenied,
        PrinterError.bluetoothOff => l10n.cartBluetoothOff,
        PrinterError.printFailed => l10n.cartPrintFailed,
      };

  /// FEAT-009 — prompt for a label (table # / customer name) then park the
  /// current cart. Cart is cleared after save so the cashier can start the
  /// next order immediately.
  Future<void> _holdOrder(
    BuildContext context,
    WidgetRef ref,
    CartState cartState,
  ) async {
    final labelCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final defaultLabel = cartState.customer?.name ?? '';
    labelCtrl.text = defaultLabel;
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.pause_circle_outline,
            size: 36, color: AppColors.accent),
        title: Text(l10n.cartHoldOrder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.cartHoldOrderDescription,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: labelCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.cartHoldLabel,
                hintText: l10n.cartHoldHint,
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, labelCtrl.text.trim()),
            child: Text(l10n.cartHoldAction),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;

    try {
      await ref.read(heldOrderServiceProvider).hold(
            state: cartState,
            label: label,
          );
      ref.read(cartNotifierProvider.notifier).clear();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.cartHeldSuccess(label))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.cartHoldFailed(e.toString()))),
      );
    }
  }

  void _openCheckout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const CheckoutSheet(),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    CartNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        final l10n = AppL10n.of(context);
        return AlertDialog(
          title: Text(l10n.cartClearTitle),
          content: Text(l10n.cartClearMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.cartClearAction),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) notifier.clear();
  }

  Future<void> _editDiscount(
    BuildContext context,
    CartNotifier notifier,
    double current,
  ) async {
    final controller = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(0) : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogCtx) {
        final l10n = AppL10n.of(dialogCtx);
        return AlertDialog(
          title: Text(l10n.cartManualDiscount),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              hintText: '0',
            ),
          ),
          actions: [
            if (current > 0)
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, 0.0),
                child: Text(l10n.actionDelete),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text) ?? 0;
                Navigator.pop(dialogCtx, parsed);
              },
              child: Text(l10n.actionSave),
            ),
          ],
        );
      },
    );
    if (result != null) notifier.setManualDiscount(result);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.itemCount, required this.onClear});

  final int itemCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(l10n.posCart, style: AppTypography.headlineLg),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '($itemCount)',
            style: AppTypography.bodyMd
                .copyWith(color: context.colors.textSecondary),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(l10n.cartClearAction),
            onPressed: onClear,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _ShareBillButton extends StatelessWidget {
  const _ShareBillButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final disabled = onPressed == null || isLoading;
    return Tooltip(
      message: l10n.cartShareBill,
      child: Material(
        color: disabled ? context.colors.disabled : AppColors.primarySurface,
        borderRadius: AppRadius.radiusMd,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: AppRadius.radiusMd,
          child: SizedBox(
            width: AppTouchTarget.primaryTablet,
            height: AppTouchTarget.primaryTablet,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.share_outlined,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Customer section ──────────────────────────────────────────────────────────

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({
    required this.customer,
    required this.onPick,
    required this.onClear,
  });

  final CustomerRow? customer;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final hasCustomer = customer != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                hasCustomer ? Icons.person : Icons.person_outline,
                size: 20,
                color: hasCustomer
                    ? AppColors.primary
                    : context.colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: hasCustomer
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer!.name, style: AppTypography.titleMd),
                          if (customer!.phone != null)
                            Text(
                              customer!.phone!,
                              style: AppTypography.labelSm.copyWith(
                                color: context.colors.textSecondary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      )
                    : Text(
                        l10n.cartAddCustomer,
                        style: AppTypography.bodyMd
                            .copyWith(color: context.colors.textSecondary),
                      ),
              ),
              if (hasCustomer)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.cartDetachCustomer,
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                )
              else
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

// ── Item tile ─────────────────────────────────────────────────────────────────

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({
    required this.index,
    required this.item,
    required this.notifier,
  });

  final int index;
  final CartItem item;
  final CartNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final subtotal = item.lineSubtotal;
    final hasNotes = item.notes != null && item.notes!.isNotEmpty;
    final optionGroups =
        ref.watch(productOptionGroupsProvider(item.product.id)).valueOrNull;
    final hasModifierGroups =
        item.selectedOptions.isNotEmpty || (optionGroups?.isNotEmpty ?? false);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.branchProduct.customName ?? item.product.name,
                      style: AppTypography.titleMd,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${formatRupiah(item.effectiveUnitPrice)} × ${item.quantity}',
                      style: AppTypography.bodySm
                          .copyWith(color: context.colors.textSecondary),
                    ),
                    if (hasModifierGroups)
                      InkWell(
                        onTap: () => _editOptions(context),
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tune_outlined,
                                  size: 12, color: AppColors.accent),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  item.selectedOptions.isEmpty
                                      ? l10n.cartModifier
                                      : item.selectedOptions
                                          .map((o) => o.optionName)
                                          .join(' · '),
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(Icons.edit_outlined,
                                  size: 12,
                                  color:
                                      AppColors.accent.withValues(alpha: 0.7)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(formatRupiah(subtotal), style: AppTypography.titleMd),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () => notifier.decrementQuantity(index),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  item.quantity.toString(),
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMd,
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () => notifier.incrementQuantity(index),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.danger,
                onPressed: () => _deleteWithUndo(context),
                tooltip: l10n.actionDelete,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _NotesField(
            notes: item.notes,
            onTap: () => _editNotes(context),
          ),
          if (hasNotes) const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  Future<void> _editOptions(BuildContext context) async {
    final picked = await OptionPickerSheet.show(
      context,
      productId: item.product.id,
      productName: item.branchProduct.customName ?? item.product.name,
      initialSelections: item.selectedOptions,
    );
    if (picked == null) return;
    notifier.updateOptions(index, picked);
  }

  /// ENH-003 — optimistic delete + 4s snackbar undo. Replaces the previous
  /// confirm dialog: peak-hour cashiers iterate too fast for a modal.
  void _deleteWithUndo(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final removed = item;
    final removedIndex = index;
    final name = removed.branchProduct.customName ?? removed.product.name;
    notifier.removeItem(removedIndex);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(buildUndoSnackBar(
      message: AppL10n.of(context).cartItemRemoved(name),
      onUndo: () => notifier.restoreItem(removed, index: removedIndex),
    ));
  }

  Future<void> _editNotes(BuildContext context) async {
    final controller = TextEditingController(text: item.notes ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) {
        final l10n = AppL10n.of(dialogCtx);
        return AlertDialog(
          title: Text(l10n.cartItemNotes),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText: l10n.cartItemNotesHint,
            ),
          ),
          actions: [
            if ((item.notes ?? '').isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, ''),
                child: Text(l10n.actionDelete),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
              child: Text(l10n.actionSave),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    notifier.updateNotes(index, result.isEmpty ? null : result);
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.notes, required this.onTap});

  final String? notes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final hasNotes = notes != null && notes!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              hasNotes
                  ? Icons.sticky_note_2_outlined
                  : Icons.add_comment_outlined,
              size: 14,
              color: hasNotes ? AppColors.accent : context.colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                hasNotes ? notes! : l10n.cartAddNote,
                style: AppTypography.labelSm.copyWith(
                  color: hasNotes
                      ? context.colors.textPrimary
                      : context.colors.textTertiary,
                  fontStyle: hasNotes ? FontStyle.italic : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: context.colors.surfaceAlt,
        borderRadius: AppRadius.radiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusMd,
          child: Icon(icon, size: 18, color: context.colors.textPrimary),
        ),
      ),
    );
  }
}

// ── Totals view ───────────────────────────────────────────────────────────────

class _CartTotalsView extends StatelessWidget {
  const _CartTotalsView({
    required this.totals,
    required this.subtotal,
    required this.discountAmount,
    required this.taxLabel,
    required this.branchSelected,
    required this.onEditDiscount,
  });

  final TotalsResult? totals;
  final double subtotal;
  final double discountAmount;
  final String taxLabel;
  final bool branchSelected;
  final VoidCallback onEditDiscount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Fallback when no branch is selected — show at least the subtotal so the
    // cashier knows the cart isn't empty/broken.
    if (totals == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _TotalRow(label: l10n.posSubtotal, value: formatRupiah(subtotal)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              branchSelected
                  ? l10n.cartCalculatingTax
                  : l10n.cartSelectBranchForTotal,
              style: AppTypography.bodySm.copyWith(color: AppColors.warning),
            ),
          ],
        ),
      );
    }

    final t = totals!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          _TotalRow(label: l10n.posSubtotal, value: formatRupiah(t.subtotal)),
          const SizedBox(height: AppSpacing.xs),
          // Discount editor — full-width tap target, primary CTA when empty.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEditDiscount,
              borderRadius: AppRadius.radiusSm,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 16,
                      color: discountAmount > 0
                          ? AppColors.accent
                          : context.colors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.posDiscount,
                      style: AppTypography.bodyMd
                          .copyWith(color: context.colors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      discountAmount > 0
                          ? '-${formatRupiah(discountAmount)}'
                          : l10n.cartAddDiscount,
                      style: AppTypography.bodyMd.copyWith(
                        color: discountAmount > 0
                            ? AppColors.accent
                            : AppColors.primary,
                        fontWeight: discountAmount > 0
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: context.colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (t.taxAmount > 0)
            _TotalRow(
              label: l10n.posTax(taxLabel),
              value: formatRupiah(t.taxAmount),
            ),
          const Divider(height: AppSpacing.lg),
          _TotalRow(
            label: l10n.posTotal,
            value: formatRupiah(t.total),
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final labelStyle = highlight
        ? AppTypography.headlineMd.copyWith(color: AppColors.primary)
        : AppTypography.bodyMd.copyWith(color: context.colors.textSecondary);
    final valueStyle = highlight
        ? AppTypography.headlineMd.copyWith(color: AppColors.primary)
        : AppTypography.bodyMd;
    return Row(
      children: [
        Text(label, style: labelStyle),
        const Spacer(),
        Text(value, style: valueStyle),
      ],
    );
  }
}
