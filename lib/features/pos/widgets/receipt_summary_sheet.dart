import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/printer_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/localized_labels.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/generated/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
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
              l10n.receiptPaymentSuccess,
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
                  _Row(
                      label: l10n.posSubtotal, value: formatRupiah(t.subtotal)),
                  if (t.subtotal - t.total - t.taxAmount > 0 ||
                      _hasDiscount(result))
                    _Row(
                      label: l10n.posDiscount,
                      value: '-${formatRupiah(_discountAmount(result))}',
                      tone: AppColors.accent,
                    ),
                  _Row(
                      label: l10n.posTax('PB1'),
                      value: formatRupiah(t.taxAmount)),
                  const Divider(),
                  _Row(
                    label: l10n.posTotal,
                    value: formatRupiah(t.total),
                    highlight: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Row(
                    label: l10n.transactionsPayment,
                    value:
                        localizedPaymentMethodLabel(l10n, result.paymentMethod),
                  ),
                  if (result.paymentReceived != null)
                    _Row(
                      label: l10n.posPaymentReceived,
                      value: formatRupiah(result.paymentReceived!),
                    ),
                  if (result.paymentChange != null && result.paymentChange! > 0)
                    _Row(
                      label: l10n.posPaymentChange,
                      value: formatRupiah(result.paymentChange!),
                      tone: AppColors.success,
                    ),
                  if (result.loyaltyPointsEarned > 0)
                    _Row(
                      label: l10n.receiptPoints,
                      value: '+${result.loyaltyPointsEarned}'
                          '${result.loyaltyPointsBalance == null ? '' : ' / ${result.loyaltyPointsBalance}'}',
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
                    label: l10n.receiptPrint,
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
                  message: l10n.receiptShare,
                  onPressed: _isSharing ? null : _onShare,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.receiptNewTransaction,
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
    final l10n = AppL10n.of(context);
    switch (r) {
      case Ok():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.receiptSentToPrinter)),
        );
      case Err(:final error):
        messenger.showSnackBar(
          SnackBar(content: Text(_errorLabel(l10n, error))),
        );
    }
  }

  Future<void> _onShare() async {
    setState(() => _isSharing = true);
    var shared = false;
    try {
      shared = await ref
          .read(shareReceiptUseCaseProvider)
          .sharePaymentReceiptImage(result.transactionId);
    } catch (_) {
      shared = false;
    }
    if (!mounted) return;
    setState(() => _isSharing = false);

    final messenger = ScaffoldMessenger.of(context);
    if (!shared) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).receiptPrepareShareFailed),
        ),
      );
      return;
    }
  }

  String _errorLabel(AppL10n l10n, PrinterError e) => switch (e) {
        PrinterError.notConnected =>
          l10n.receiptPrinterNotConnectedOpenSettings,
        PrinterError.deviceNotFound => l10n.cartPrinterNotFound,
        PrinterError.permissionDenied =>
          l10n.receiptBluetoothPermissionDeniedOpenSettings,
        PrinterError.bluetoothOff => l10n.cartBluetoothOff,
        PrinterError.printFailed => l10n.cartPrintFailed,
      };
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.isLoading,
    required this.message,
    required this.onPressed,
  });

  final bool isLoading;
  final String message;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    return Tooltip(
      message: message,
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
