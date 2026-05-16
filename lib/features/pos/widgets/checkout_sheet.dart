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
import '../cart_provider.dart';
import '../checkout_use_case.dart';
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
    final canSubmit = !_isSubmitting &&
        (!isCash || received >= totals.total) &&
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
                  color: AppColors.border,
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
        CheckoutError.databaseError =>
          'Gagal menyimpan transaksi. Coba lagi.',
      };
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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
          style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
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
        color: AppColors.textSecondary,
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
