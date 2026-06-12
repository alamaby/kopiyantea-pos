import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/localized_labels.dart';
import '../../core/utils/transaction_numbers.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/utils/result.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_provider.dart';
import '../customers/customer_providers.dart';
import '../pos/print_receipt_use_case.dart';
import '../pos/share_receipt_use_case.dart';
import 'transaction_providers.dart';
import 'void_transaction_use_case.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(transactionDetailProvider(transactionId));
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactionsDetailTitle)),
      body: detailAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: l10n.transactionsLoadFailed,
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (data) {
          if (data == null) {
            return AppEmptyState(
              title: l10n.transactionsNotFound,
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
    final transactionNumber = displayTransactionRowNumber(tx);
    final customerAsync = tx.customerId == null
        ? null
        : ref.watch(customerByIdProvider(tx.customerId!));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeaderCard(
          tx: tx,
          transactionNumber: transactionNumber,
          voided: voided,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (customerAsync != null)
          customerAsync.maybeWhen(
            data: (c) => c == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _CustomerCard(
                      customer: c,
                      transactionPoints: _transactionPointDelta(data),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        _ItemsCard(items: data.items, optionsByItemId: data.optionsByItemId),
        const SizedBox(height: AppSpacing.lg),
        _TotalsCard(tx: tx),
        const SizedBox(height: AppSpacing.lg),
        _PaymentCard(tx: tx),
        const SizedBox(height: AppSpacing.lg),
        _ActionsCard(tx: tx, voided: voided),
      ],
    );
  }
}

int _transactionPointDelta(TransactionDetailData data) =>
    data.pointLedger.fold<int>(0, (sum, row) => sum + row.pointsDelta);

// ── Actions (ENH-007 Reprint + ENH-008 Void) ─────────────────────────────────

class _ActionsCard extends ConsumerStatefulWidget {
  const _ActionsCard({required this.tx, required this.voided});
  final TransactionRow tx;

  /// True when *this* row is itself the void row. We hide both reprint and
  /// "Batalkan" on void rows — original is the user-facing record.
  final bool voided;

  @override
  ConsumerState<_ActionsCard> createState() => _ActionsCardState();
}

class _ActionsCardState extends ConsumerState<_ActionsCard> {
  bool _isSharing = false;
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tx = widget.tx;
    if (widget.voided) {
      // It's a void row — nothing to act on.
      return const SizedBox.shrink();
    }
    final voidAsync = ref.watch(voidForTransactionProvider(tx.id));
    final alreadyVoided = voidAsync.maybeWhen(
      data: (v) => v != null,
      orElse: () => false,
    );
    final currentUser = ref.watch(currentUserProvider);
    // Owner + manager only — kasir tidak boleh void demi kontrol shrinkage.
    final canVoid = currentUser != null &&
        (currentUser.globalRole == GlobalRole.owner ||
            currentUser.globalRole == GlobalRole.manager);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(l10n.transactionsActions),
          const SizedBox(height: AppSpacing.sm),
          if (alreadyVoided) ...[
            voidAsync.maybeWhen(
              data: (v) => v == null
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: AppRadius.radiusSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel_outlined,
                              size: 18, color: AppColors.danger),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              v.voidReason == null || v.voidReason!.isEmpty
                                  ? l10n.transactionsAlreadyVoided
                                  : l10n.transactionsAlreadyVoidedReason(
                                      v.voidReason!,
                                    ),
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: l10n.receiptShare,
            icon: Icons.ios_share_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: _isSharing ? null : () => _share(context),
            isLoading: _isSharing,
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.receiptReprint,
            icon: Icons.print_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: _isPrinting ? null : () => _reprint(context),
            isLoading: _isPrinting,
            fullWidth: true,
          ),
          if (canVoid && !alreadyVoided) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.transactionsVoidAction,
              icon: Icons.cancel_outlined,
              variant: AppButtonVariant.danger,
              onPressed: () => _confirmVoid(context, ref),
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    setState(() => _isSharing = true);
    final renderObject = context.findRenderObject();
    final box = renderObject is RenderBox ? renderObject : null;
    try {
      final shared =
          await ref.read(shareReceiptUseCaseProvider).sharePaymentReceiptImage(
                widget.tx.id,
                sharePositionOrigin: box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size,
              );
      if (!context.mounted) return;
      if (!shared) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.receiptCannotShare)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.receiptShareFailed(
            _shareReceiptErrorLabel(l10n, e),
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _shareReceiptErrorLabel(AppL10n l10n, Object error) {
    if (error is StateError &&
        error.message == shareReceiptImageEncodeFailedCode) {
      return l10n.receiptCreateImageFailed;
    }
    return error.toString();
  }

  Future<void> _reprint(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    setState(() => _isPrinting = true);
    try {
      final result =
          await ref.read(printReceiptUseCaseProvider).print(widget.tx.id);
      if (!context.mounted) return;
      switch (result) {
        case Ok():
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.receiptSentToPrinter)),
          );
        case Err(:final error):
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.receiptPrintFailed(error.name))),
          );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _confirmVoid(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined,
            size: 36, color: AppColors.danger),
        title: Text(l10n.transactionsVoidTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.transactionsVoidMessage(
                displayTransactionRowNumber(widget.tx),
              ),
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.transactionsVoidReasonLabel,
                hintText: l10n.transactionsVoidReasonHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.transactionsVoidNo),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.transactionsVoidAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(voidTransactionUseCaseProvider).voidTx(
          originalId: widget.tx.id,
          reason: reasonCtrl.text.trim(),
        );
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(transactionDetailProvider(widget.tx.id));
        ref.invalidate(voidForTransactionProvider(widget.tx.id));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.transactionsVoidedSuccess)),
        );
      case Err(:final error):
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.transactionsVoidFailed(error.name))),
        );
    }
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.transactionPoints,
  });

  final CustomerRow customer;
  final int transactionPoints;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
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
                Text(l10n.transactionsCustomer.toUpperCase(),
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
                if (transactionPoints != 0)
                  Text(
                    l10n.transactionsPointsDelta(
                      '${transactionPoints > 0 ? '+' : ''}$transactionPoints',
                    ),
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
                l10n.transactionsPoints(customer.loyaltyPoints),
                style: AppTypography.labelSm.copyWith(color: AppColors.accent),
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
    required this.transactionNumber,
    required this.voided,
  });

  final TransactionRow tx;
  final String transactionNumber;
  final bool voided;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#$transactionNumber',
                style: AppTypography.headlineLg.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (voided)
                AppBadge(
                  label: l10n.transactionsStatusVoided,
                  icon: Icons.cancel_outlined,
                  tone: AppBadgeTone.danger,
                )
              else
                AppBadge(
                  label: l10n.transactionsStatusCompleted,
                  icon: Icons.check_circle_outline,
                  tone: AppBadgeTone.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatDateTime(tx.clientCreatedAt),
            style: AppTypography.bodyMd
                .copyWith(color: context.colors.textSecondary),
          ),
          if (voided && tx.voidReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.transactionsVoidReason(tx.voidReason!),
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items, required this.optionsByItemId});

  final List<TransactionItemRow> items;
  final Map<String, List<TransactionItemOptionRow>> optionsByItemId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l10n.transactionsItems),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.lg),
            _ItemRow(
              item: items[i],
              options: optionsByItemId[items[i].id] ?? const [],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.options});

  final TransactionItemRow item;
  final List<TransactionItemOptionRow> options;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
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
          l10n.transactionsPerItem(formatRupiah(item.priceSnapshot)),
          style: AppTypography.bodySm
              .copyWith(color: context.colors.textSecondary),
        ),
        // FEAT-001 — modifier snapshot list.
        if (options.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.tune_outlined,
                      size: 12, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${o.optionGroupNameSnapshot}: ${o.optionNameSnapshot}'
                      '${o.priceDeltaSnapshot == 0 ? "" : " (+${formatRupiah(o.priceDeltaSnapshot)})"}',
                      style: AppTypography.labelSm.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
    final l10n = AppL10n.of(context);
    final taxLabel = tx.taxInclusiveSnapshot
        ? l10n.transactionsTaxInclusive(tx.taxLabelSnapshot)
        : l10n.transactionsTax(tx.taxLabelSnapshot);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l10n.transactionsSummary),
          const SizedBox(height: AppSpacing.sm),
          _KV(label: l10n.posSubtotal, value: formatRupiah(tx.subtotal)),
          if (tx.discountAmount > 0)
            _KV(
              label: l10n.posDiscount,
              value: '-${formatRupiah(tx.discountAmount)}',
              valueColor: AppColors.accent,
            ),
          _KV(
            label: taxLabel,
            value: formatRupiah(tx.taxAmount),
          ),
          const Divider(height: AppSpacing.lg),
          _KV(
            label: l10n.posTotal,
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
    final l10n = AppL10n.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l10n.transactionsPayment),
          const SizedBox(height: AppSpacing.sm),
          _KV(
            label: l10n.paymentMethod,
            value: localizedPaymentMethodLabel(l10n, tx.paymentMethod),
          ),
          if (tx.bankAccountSnapshot != null &&
              tx.bankAccountSnapshot!.isNotEmpty)
            _KV(label: l10n.paymentBankAccount, value: tx.bankAccountSnapshot!),
          if (tx.paymentReceived != null)
            _KV(
              label: l10n.posPaymentReceived,
              value: formatRupiah(tx.paymentReceived!),
            ),
          if (tx.paymentChange != null && tx.paymentChange! > 0)
            _KV(
              label: l10n.posPaymentChange,
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
