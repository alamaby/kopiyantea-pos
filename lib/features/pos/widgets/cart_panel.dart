import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pricing/pricing.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../cart_provider.dart';
import '../cart_state.dart';
import 'checkout_sheet.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartNotifierProvider);
    final notifier = ref.read(cartNotifierProvider.notifier);

    if (cartState.items.isEmpty) {
      return const AppEmptyState(
        title: 'Keranjang kosong',
        icon: Icons.shopping_cart_outlined,
        message: 'Tap produk dari menu untuk menambahkannya.',
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
            child: AppButton(
              label: totals == null
                  ? 'Bayar'
                  : 'Bayar ${formatRupiah(totals.total)}',
              onPressed: totals != null && totals.total > 0
                  ? () => _openCheckout(context)
                  : null,
              size: AppButtonSize.primary,
              fullWidth: true,
              icon: Icons.payment_outlined,
            ),
          ),
        ),
      ],
    );
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
      builder: (_) => AlertDialog(
        title: const Text('Kosongkan keranjang?'),
        content: const Text('Semua item akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
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
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Diskon Manual'),
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
              child: const Text('Hapus'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text) ?? 0;
              Navigator.pop(dialogCtx, parsed);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text('Keranjang', style: AppTypography.headlineLg),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '($itemCount)',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Kosongkan'),
            onPressed: onClear,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.index,
    required this.item,
    required this.notifier,
  });

  final int index;
  final CartItem item;
  final CartNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final subtotal = item.priceSnapshot * item.quantity;
    final hasNotes = item.notes != null && item.notes!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
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
                      '${formatRupiah(item.priceSnapshot)} × ${item.quantity}',
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.textSecondary),
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
                onPressed: () => _confirmDelete(context),
                tooltip: 'Hapus',
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

  Future<void> _confirmDelete(BuildContext context) async {
    final name = item.branchProduct.customName ?? item.product.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus item?'),
        content: Text('"$name" akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) notifier.removeItem(index);
  }

  Future<void> _editNotes(BuildContext context) async {
    final controller = TextEditingController(text: item.notes ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Catatan Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: 'mis. tanpa gula, extra shot, less ice',
          ),
        ),
        actions: [
          if ((item.notes ?? '').isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, ''),
              child: const Text('Hapus'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogCtx, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
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
    final hasNotes = notes != null && notes!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              hasNotes ? Icons.sticky_note_2_outlined : Icons.add_comment_outlined,
              size: 14,
              color: hasNotes ? AppColors.accent : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                hasNotes ? notes! : 'Tambah catatan',
                style: AppTypography.labelSm.copyWith(
                  color: hasNotes
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
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
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.radiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusMd,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
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
    // Fallback when no branch is selected — show at least the subtotal so the
    // cashier knows the cart isn't empty/broken.
    if (totals == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _TotalRow(label: 'Subtotal', value: formatRupiah(subtotal)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              branchSelected
                  ? 'Menghitung pajak…'
                  : 'Pilih cabang untuk menghitung total',
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
          _TotalRow(label: 'Subtotal', value: formatRupiah(t.subtotal)),
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
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Diskon',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      discountAmount > 0
                          ? '-${formatRupiah(discountAmount)}'
                          : 'Tambah diskon',
                      style: AppTypography.bodyMd.copyWith(
                        color: discountAmount > 0
                            ? AppColors.accent
                            : AppColors.primary,
                        fontWeight: discountAmount > 0
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _TotalRow(
            label: 'Pajak ($taxLabel)',
            value: formatRupiah(t.taxAmount),
          ),
          const Divider(height: AppSpacing.lg),
          _TotalRow(
            label: 'Total',
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
        : AppTypography.bodyMd.copyWith(color: AppColors.textSecondary);
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
