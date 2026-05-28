import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/domain/enums.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_button.dart';
import '../checkout_use_case.dart';
import '../print_receipt_use_case.dart';
import '../share_receipt_use_case.dart';

/// Post-checkout receipt summary. The cart has already been cleared by the
/// caller (checkout_sheet) — this is a read-only confirmation surface.
class ReceiptSummarySheet extends ConsumerStatefulWidget {
  const ReceiptSummarySheet({required this.result, super.key});

  final CheckoutResult result;

  @override
  ConsumerState<ReceiptSummarySheet> createState() =>
      _ReceiptSummarySheetState();
}

class _ReceiptSummarySheetState extends ConsumerState<ReceiptSummarySheet> {
  bool _isPrinting = false;
  bool _isSharing = false;

  CheckoutResult get result => widget.result;

  static const _methodLabels = {
    PaymentMethod.cash: 'Tunai',
    PaymentMethod.qris: 'QRIS',
    PaymentMethod.debit: 'Debit',
    PaymentMethod.credit: 'Kredit',
    PaymentMethod.transfer: 'Transfer',
    PaymentMethod.other: 'Lainnya',
  };

  @override
  Widget build(BuildContext context) {
    final t = result.totals;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: AppSpacing.xl),
            const Center(
              child: Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 72,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Pembayaran Berhasil',
              style: AppTypography.headlineLg,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '#${result.transactionNumber}',
              style: AppTypography.bodySm.copyWith(
                color: context.colors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: AppRadius.radiusLg,
              ),
              child: Column(
                children: [
                  _Row(label: 'Subtotal', value: formatRupiah(t.subtotal)),
                  if (t.subtotal - t.total - t.taxAmount > 0 ||
                      _hasDiscount(result))
                    _Row(
                      label: 'Diskon',
                      value: '-${formatRupiah(_discountAmount(result))}',
                      tone: AppColors.accent,
                    ),
                  _Row(label: 'Pajak', value: formatRupiah(t.taxAmount)),
                  const Divider(),
                  _Row(
                    label: 'Total',
                    value: formatRupiah(t.total),
                    highlight: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Row(
                    label: 'Pembayaran',
                    value: _methodLabels[result.paymentMethod] ?? '-',
                  ),
                  if (result.paymentReceived != null)
                    _Row(
                      label: 'Diterima',
                      value: formatRupiah(result.paymentReceived!),
                    ),
                  if (result.paymentChange != null && result.paymentChange! > 0)
                    _Row(
                      label: 'Kembalian',
                      value: formatRupiah(result.paymentChange!),
                      tone: AppColors.success,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cetak Struk',
                    variant: AppButtonVariant.secondary,
                    icon: Icons.print_outlined,
                    onPressed: _isPrinting ? null : _onPrint,
                    isLoading: _isPrinting,
                    fullWidth: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ShareButton(
                  isLoading: _isSharing,
                  onPressed: _isSharing ? null : _onShare,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Transaksi Baru',
              icon: Icons.add,
              onPressed: () => Navigator.of(context).pop(),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  bool _hasDiscount(CheckoutResult r) => _discountAmount(r) > 0;

  // Derive manual discount: subtotal - (taxable base) where taxable base
  // equals total - taxAmount in exclusive mode. For Phase 4.2 simplicity,
  // we surface 0 if not derivable.
  double _discountAmount(CheckoutResult r) {
    // For exclusive tax: subtotal - (total - tax) = discount
    // For inclusive tax: subtotal - total = discount (tax already in total)
    final implied = r.totals.subtotal - r.totals.total + r.totals.taxAmount;
    return implied > 0.01 ? implied : 0;
  }

  Future<void> _onPrint() async {
    setState(() => _isPrinting = true);
    final useCase = ref.read(printReceiptUseCaseProvider);
    final r = await useCase.print(result.transactionId);
    if (!mounted) return;
    setState(() => _isPrinting = false);

    final messenger = ScaffoldMessenger.of(context);
    switch (r) {
      case Ok():
        messenger.showSnackBar(
          const SnackBar(content: Text('Struk dikirim ke printer')),
        );
      case Err(:final error):
        messenger.showSnackBar(
          SnackBar(content: Text(_errorLabel(error))),
        );
    }
  }

  Future<void> _onShare() async {
    setState(() => _isSharing = true);
    final text = await ref
        .read(shareReceiptUseCaseProvider)
        .buildText(result.transactionId);
    if (!mounted) return;
    setState(() => _isSharing = false);

    final messenger = ScaffoldMessenger.of(context);
    if (text == null || text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menyiapkan struk untuk dibagikan')),
      );
      return;
    }

    await Share.share(
      text,
      subject: 'Struk #${result.transactionNumber}',
    );
  }

  String _errorLabel(PrinterError e) => switch (e) {
        PrinterError.notConnected =>
          'Printer belum terhubung — buka Pengaturan > Printer',
        PrinterError.deviceNotFound => 'Printer tidak ditemukan',
        PrinterError.permissionDenied =>
          'Izin Bluetooth ditolak — buka Pengaturan aplikasi',
        PrinterError.bluetoothOff => 'Bluetooth tidak aktif',
        PrinterError.printFailed => 'Gagal mencetak struk',
      };
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    return Tooltip(
      message: 'Bagikan struk',
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

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.highlight = false,
    this.tone,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final labelStyle = highlight
        ? AppTypography.headlineMd
        : AppTypography.bodyMd.copyWith(color: context.colors.textSecondary);
    final valueStyle = highlight
        ? AppTypography.headlineMd.copyWith(color: AppColors.primary)
        : AppTypography.bodyMd.copyWith(color: tone);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(label, style: labelStyle),
          const Spacer(),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
