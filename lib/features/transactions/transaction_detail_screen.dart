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
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../customers/customer_providers.dart';
import 'transaction_providers.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(transactionDetailProvider(transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: detailAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat transaksi',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (data) {
          if (data == null) {
            return const AppEmptyState(
              title: 'Transaksi tidak ditemukan',
              icon: Icons.search_off_outlined,
            );
          }
          return _DetailBody(data: data);
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.data});

  final TransactionDetailData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = data.transaction;
    final voided = tx.status == TransactionStatus.voided;
    final shortId = tx.id.substring(0, 8).toUpperCase();
    final customerAsync = tx.customerId == null
        ? null
        : ref.watch(customerByIdProvider(tx.customerId!));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeaderCard(tx: tx, shortId: shortId, voided: voided),
        const SizedBox(height: AppSpacing.lg),
        if (customerAsync != null)
          customerAsync.maybeWhen(
            data: (c) => c == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _CustomerCard(customer: c),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        _ItemsCard(items: data.items),
        const SizedBox(height: AppSpacing.lg),
        _TotalsCard(tx: tx),
        const SizedBox(height: AppSpacing.lg),
        _PaymentCard(tx: tx),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final CustomerRow customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primarySurface,
            child: Text(
              customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
              style:
                  AppTypography.titleMd.copyWith(color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PELANGGAN',
                    style: AppTypography.labelSm.copyWith(
                      color: context.colors.textSecondary,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: AppSpacing.xs),
                Text(customer.name, style: AppTypography.titleMd),
                if (customer.phone != null)
                  Text(
                    customer.phone!,
                    style: AppTypography.bodySm.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (customer.loyaltyPoints > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: AppRadius.radiusSm,
              ),
              child: Text(
                '${customer.loyaltyPoints} poin',
                style:
                    AppTypography.labelSm.copyWith(color: AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.tx,
    required this.shortId,
    required this.voided,
  });

  final TransactionRow tx;
  final String shortId;
  final bool voided;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#$shortId',
                style: AppTypography.headlineLg.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (voided)
                const AppBadge(
                  label: 'Dibatalkan',
                  icon: Icons.cancel_outlined,
                  tone: AppBadgeTone.danger,
                )
              else
                const AppBadge(
                  label: 'Selesai',
                  icon: Icons.check_circle_outline,
                  tone: AppBadgeTone.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatDateTime(tx.clientCreatedAt),
            style:
                AppTypography.bodyMd.copyWith(color: context.colors.textSecondary),
          ),
          if (voided && tx.voidReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Alasan pembatalan: ${tx.voidReason}',
              style:
                  AppTypography.bodySm.copyWith(color: context.colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items});

  final List<TransactionItemRow> items;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Item'),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.lg),
            _ItemRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final TransactionItemRow item;

  @override
  Widget build(BuildContext context) {
    final qty = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.nameSnapshot} × $qty',
                style: AppTypography.titleMd,
              ),
            ),
            Text(formatRupiah(item.subtotal), style: AppTypography.titleMd),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${formatRupiah(item.priceSnapshot)} per item',
          style: AppTypography.bodySm.copyWith(color: context.colors.textSecondary),
        ),
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.sticky_note_2_outlined,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  item.notes!,
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.tx});

  final TransactionRow tx;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Ringkasan'),
          const SizedBox(height: AppSpacing.sm),
          _KV(label: 'Subtotal', value: formatRupiah(tx.subtotal)),
          if (tx.discountAmount > 0)
            _KV(
              label: 'Diskon',
              value: '-${formatRupiah(tx.discountAmount)}',
              valueColor: AppColors.accent,
            ),
          _KV(
            label:
                'Pajak (${tx.taxLabelSnapshot}${tx.taxInclusiveSnapshot ? " inc." : ""})',
            value: formatRupiah(tx.taxAmount),
          ),
          const Divider(height: AppSpacing.lg),
          _KV(
            label: 'Total',
            value: formatRupiah(tx.total),
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.tx});

  final TransactionRow tx;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Pembayaran'),
          const SizedBox(height: AppSpacing.sm),
          _KV(label: 'Metode', value: paymentMethodLabel(tx.paymentMethod)),
          if (tx.paymentReceived != null)
            _KV(label: 'Diterima', value: formatRupiah(tx.paymentReceived!)),
          if (tx.paymentChange != null && tx.paymentChange! > 0)
            _KV(
              label: 'Kembalian',
              value: formatRupiah(tx.paymentChange!),
              valueColor: AppColors.success,
            ),
        ],
      ),
    );
  }
}

// ── Primitives ────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

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

class _KV extends StatelessWidget {
  const _KV({
    required this.label,
    required this.value,
    this.highlight = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = highlight
        ? AppTypography.headlineMd
        : AppTypography.bodyMd.copyWith(color: context.colors.textSecondary);
    final valueStyle = highlight
        ? AppTypography.headlineMd.copyWith(color: AppColors.primary)
        : AppTypography.bodyMd.copyWith(color: valueColor);
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
