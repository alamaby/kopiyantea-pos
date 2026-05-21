import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../bank_accounts/bank_account_picker_sheet.dart';
import '../cart_provider.dart';
import '../checkout_use_case.dart';
import 'qris_display.dart';
import 'receipt_summary_sheet.dart';

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  PaymentMethod _method = PaymentMethod.cash;
  final _receivedCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _receivedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final totals = cartNotifier.totals;
    if (totals == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('Tidak ada total untuk dibayar'),
      );
    }

    final received = double.tryParse(_receivedCtrl.text) ?? 0;
    final change = received - totals.total;
    final isCash = _method == PaymentMethod.cash;
    final isTransfer = _method == PaymentMethod.transfer;
    // FEAT-015 — block submit until bank account chosen.
    final hasBankAccount =
        ref.watch(cartNotifierProvider.select((c) => c.bankAccount != null));
    final canSubmit = !_isSubmitting &&
        (!isCash || received >= totals.total) &&
        (!isTransfer || hasBankAccount) &&
        totals.total > 0;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Bayar', style: AppTypography.headlineLg),
            const SizedBox(height: AppSpacing.md),
            _TotalDisplay(total: totals.total),
            const SizedBox(height: AppSpacing.xl),
            _SectionTitle('Metode Pembayaran'),
            const SizedBox(height: AppSpacing.sm),
            _MethodPicker(
              selected: _method,
              onChanged: (m) => setState(() {
                _method = m;
                if (!isCash) _receivedCtrl.clear();
              }),
            ),
            if (_method == PaymentMethod.qris) ...[
              const SizedBox(height: AppSpacing.xl),
              _QrisSection(
                total: totals.total,
                onConfirm: () => _submit(totals.total, null),
              ),
            ],
            if (_method == PaymentMethod.transfer) ...[
              const SizedBox(height: AppSpacing.xl),
              const _BankAccountSection(),
            ],
            if (isCash) ...[
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle('Diterima'),
              const SizedBox(height: AppSpacing.sm),
              _QuickAmountRow(
                total: totals.total,
                onPicked: (amount) {
                  setState(() {
                    _receivedCtrl.text = amount.toStringAsFixed(0);
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _receivedCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '0',
                ),
                style: AppTypography.headlineMd,
                onChanged: (_) => setState(() {}),
              ),
              if (received > 0) ...[
                const SizedBox(height: AppSpacing.md),
                _ChangeDisplay(
                  change: change,
                  insufficient: received < totals.total,
                ),
              ],
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySm
                            .copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Konfirmasi Pembayaran',
              icon: Icons.check_circle_outline,
              onPressed: canSubmit
                  ? () => _submit(totals.total, isCash ? received : null)
                  : null,
              isLoading: _isSubmitting,
              size: AppButtonSize.primary,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(double total, double? paymentReceived) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final useCase = ref.read(checkoutUseCaseProvider);
    final cart = ref.read(cartNotifierProvider);
    final result = await useCase.checkout(
      cart: cart,
      paymentMethod: _method,
      paymentReceived: paymentReceived,
    );

    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        HapticFeedback.mediumImpact();
        ref.read(cartNotifierProvider.notifier).clear();

        // Capture root navigator BEFORE popping — `context` becomes stale
        // once this widget is disposed.
        final nav = Navigator.of(context, rootNavigator: true);

        // Pop every bottom sheet in the stack (this checkout sheet + the
        // cart sheet on mobile). On tablet only the checkout sheet pops.
        nav.popUntil((route) => route is! ModalBottomSheetRoute);

        // Show the receipt directly on top of the POS screen.
        await showModalBottomSheet<void>(
          context: nav.context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          useRootNavigator: true,
          builder: (_) => ReceiptSummarySheet(result: value),
        );
      case Err(:final error):
        setState(() {
          _isSubmitting = false;
          _errorMessage = _errorLabel(error);
        });
    }
  }

  String _errorLabel(CheckoutError e) => switch (e) {
        CheckoutError.noBranch => 'Pilih cabang terlebih dahulu',
        CheckoutError.emptyCart => 'Keranjang kosong',
        CheckoutError.invalidPayment => 'Pembayaran tidak mencukupi',
        CheckoutError.bankAccountMissing =>
          'Pilih rekening tujuan transfer dulu',
        CheckoutError.databaseError =>
          'Gagal menyimpan transaksi. Coba lagi.',
      };
}

/// FEAT-015 — Transfer payment: cashier picks one of owner's bank accounts.
/// The selection is stored in CartState so it persists if the sheet is
/// dismissed and reopened.
class _BankAccountSection extends ConsumerWidget {
  const _BankAccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartNotifierProvider);
    final selected = cart.bankAccount;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.radiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined,
                  color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.sm),
              Text('Rekening Tujuan',
                  style: AppTypography.titleMd
                      .copyWith(color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (selected == null)
            Text(
              'Pilih rekening yang akan menerima transfer. '
              'Owner mengatur daftar rekening di Pengaturan → Rekening Bank.',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.primaryDark),
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.radiusSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected.bankName, style: AppTypography.titleMd),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    selected.accountNumber,
                    style: AppTypography.bodyMd.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'a.n. ${selected.accountHolder}',
                    style: AppTypography.bodySm
                        .copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: selected == null ? 'Pilih Rekening' : 'Ganti Rekening',
            icon: Icons.swap_horiz_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              final picked = await BankAccountPickerSheet.show(
                context,
                selectedId: selected?.id,
              );
              if (picked != null) {
                ref.read(cartNotifierProvider.notifier)
                    .setBankAccount(picked);
              }
            },
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// FEAT-013 — QRIS branch shortcut at checkout. Shows a "Tampilkan QRIS"
/// CTA that opens the fullscreen QR sheet; tapping "Pembayaran Diterima"
/// inside that sheet fires [onConfirm] to commit the transaction. Falls
/// back to a hint when the branch has no QR uploaded.
class _QrisSection extends ConsumerWidget {
  const _QrisSection({required this.total, required this.onConfirm});
  final double total;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartNotifierProvider);
    final branch = cart.branch;
    final hasQr =
        branch?.qrisImageUrl != null && branch!.qrisImageUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.radiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_outlined,
                  color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.sm),
              Text('Pembayaran QRIS',
                  style: AppTypography.titleMd
                      .copyWith(color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasQr
                ? 'Tampilkan QR di bawah ke customer untuk discan. '
                    'Setelah pembayaran terverifikasi di m-banking, '
                    'tap "Pembayaran Diterima".'
                : 'Cabang ini belum upload QRIS. Owner perlu mengaturnya '
                    'di Pengaturan → QRIS Statis.',
            style: AppTypography.bodySm
                .copyWith(color: AppColors.primaryDark),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: hasQr ? 'Tampilkan QRIS' : 'QRIS Belum Tersedia',
            icon: Icons.qr_code_2_outlined,
            onPressed: !hasQr || branch == null
                ? null
                : () => QrisDisplaySheet.show(
                      context,
                      branch: branch,
                      amount: total,
                      onConfirmPaid: () {
                        Navigator.of(context).pop();
                        onConfirm();
                      },
                    ),
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _TotalDisplay extends StatelessWidget {
  const _TotalDisplay({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total',
          style: AppTypography.bodyMd.copyWith(color: context.colors.textSecondary),
        ),
        Text(
          formatRupiah(total),
          style: AppTypography.displayMd.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.labelSm.copyWith(
        color: context.colors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MethodPicker extends StatelessWidget {
  const _MethodPicker({required this.selected, required this.onChanged});
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  static const _labels = {
    PaymentMethod.cash: 'Tunai',
    PaymentMethod.qris: 'QRIS',
    PaymentMethod.debit: 'Debit',
    PaymentMethod.credit: 'Kredit',
    PaymentMethod.transfer: 'Transfer',
    PaymentMethod.other: 'Lainnya',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final m in PaymentMethod.values)
          ChoiceChip(
            label: Text(_labels[m]!),
            selected: selected == m,
            onSelected: (_) => onChanged(m),
            selectedColor: AppColors.primarySurface,
          ),
      ],
    );
  }
}

class _QuickAmountRow extends StatelessWidget {
  const _QuickAmountRow({required this.total, required this.onPicked});
  final double total;
  final ValueChanged<double> onPicked;

  List<double> _suggest() {
    final exact = total.ceilToDouble();
    final rounded50k = (total / 50000).ceil() * 50000.0;
    final rounded100k = (total / 100000).ceil() * 100000.0;
    final next100k = rounded100k + 100000;
    final suggestions = <double>{exact, rounded50k, rounded100k, next100k}
        .where((v) => v >= total)
        .toList()
      ..sort();
    return suggestions.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final amounts = _suggest();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final a in amounts)
          OutlinedButton(
            onPressed: () => onPicked(a),
            child: Text(formatRupiah(a)),
          ),
      ],
    );
  }
}

class _ChangeDisplay extends StatelessWidget {
  const _ChangeDisplay({required this.change, required this.insufficient});
  final double change;
  final bool insufficient;

  @override
  Widget build(BuildContext context) {
    final color = insufficient ? AppColors.danger : AppColors.success;
    final label = insufficient ? 'Kurang' : 'Kembalian';
    final value = insufficient ? -change : change;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: insufficient
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFE0F2FE),
        borderRadius: AppRadius.radiusMd,
      ),
      child: Row(
        children: [
          Icon(
            insufficient ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.bodyMd.copyWith(color: color)),
          const Spacer(),
          Text(
            formatRupiah(value),
            style: AppTypography.headlineMd.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
