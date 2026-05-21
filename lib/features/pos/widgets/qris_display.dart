import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading_indicator.dart';

/// FEAT-013 — fullscreen QRIS display.
///
/// Shows the branch's static QR with an optional [amount] tag (used at
/// checkout) so customer's banking app can match against the displayed
/// nominal. Tap-outside dismisses; explicit "Selesai" button confirms
/// payment at checkout flow.
class QrisDisplaySheet extends StatelessWidget {
  const QrisDisplaySheet({
    required this.branch,
    this.amount,
    this.onConfirmPaid,
    super.key,
  });

  final BranchRow branch;

  /// When non-null, shows "Bayar [amount]" header — used at checkout.
  /// When null, this is a free-standing QR preview (POS AppBar quick-view).
  final double? amount;

  /// Optional — called when the user taps "Pembayaran Diterima" at the
  /// checkout flow. The caller is responsible for closing the sheet.
  final VoidCallback? onConfirmPaid;

  static Future<void> show(
    BuildContext context, {
    required BranchRow branch,
    double? amount,
    VoidCallback? onConfirmPaid,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        isDismissible: onConfirmPaid == null,
        enableDrag: onConfirmPaid == null,
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (_) => QrisDisplaySheet(
          branch: branch,
          amount: amount,
          onConfirmPaid: onConfirmPaid,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = branch.qrisImageUrl;
    if (url == null || url.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_outlined,
                size: 56, color: context.colors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text('QRIS belum diunggah', style: AppTypography.titleMd),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Owner perlu upload QRIS lewat Pengaturan → QRIS Statis '
              'untuk cabang ${branch.name}.',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Tutup',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
              fullWidth: true,
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              amount == null ? 'Scan untuk Bayar' : 'Bayar via QRIS',
              style: AppTypography.headlineMd,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              branch.name,
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
            if (amount != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: AppRadius.radiusFull,
                ),
                child: Text(
                  formatRupiah(amount!),
                  style: AppTypography.headlineMd
                      .copyWith(color: AppColors.primaryDark),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 360,
                maxHeight: 360,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: AppRadius.radiusLg,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const Center(child: AppLoadingIndicator()),
                    errorWidget: (_, __, ___) => Container(
                      color: context.colors.surfaceAlt,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_outlined,
                                size: 48, color: AppColors.danger),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              'Gambar tidak tersedia offline.\n'
                              'Sambungkan internet untuk memuat ulang.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Customer scan QR di atas dengan aplikasi mobile banking '
              'atau e-wallet (GoPay, OVO, DANA, ShopeePay).',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (onConfirmPaid != null) ...[
              AppButton(
                label: 'Pembayaran Diterima',
                icon: Icons.check_circle_outline,
                onPressed: onConfirmPaid,
                size: AppButtonSize.primary,
                fullWidth: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Batal',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
                fullWidth: true,
              ),
            ] else
              AppButton(
                label: 'Tutup',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
                fullWidth: true,
              ),
          ],
        ),
      ),
    );
  }
}
