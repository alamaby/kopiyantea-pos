import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../settings/branch_selection_provider.dart';
import 'transaction_providers.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(selectedBranchProvider);

    return Scaffold(
      appBar: AppBar(
        title: branchAsync.maybeWhen(
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Transaksi'),
              if (b != null)
                Text(
                  b.name,
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
          orElse: () => const Text('Transaksi'),
        ),
      ),
      body: branchAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat cabang',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branch) {
          if (branch == null) {
            return const AppEmptyState(
              title: 'Belum memilih cabang',
              icon: Icons.store_outlined,
              message: 'Pilih cabang aktif di Pengaturan.',
            );
          }
          return _TransactionList(branchId: branch.id);
        },
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _TransactionList extends ConsumerWidget {
  const _TransactionList({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(branchTransactionsProvider(branchId));

    return txAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => AppEmptyState(
        title: 'Gagal memuat transaksi',
        icon: Icons.error_outline,
        message: e.toString(),
      ),
      data: (txns) {
        if (txns.isEmpty) {
          return const AppEmptyState(
            title: 'Belum ada transaksi',
            icon: Icons.receipt_long_outlined,
            message: 'Transaksi yang Anda buat di Kasir akan muncul di sini.',
          );
        }
        final entries = _groupByDate(txns);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          itemCount: entries.length,
          itemBuilder: (_, i) => switch (entries[i]) {
            _Header(:final label) => _DateHeader(label: label),
            _Row(:final tx) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TxTile(tx: tx),
              ),
          },
        );
      },
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final TransactionRow tx;

  @override
  Widget build(BuildContext context) {
    final shortId = tx.id.substring(0, 8).toUpperCase();
    final voided = tx.status == TransactionStatus.voided;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => context.push('/transactions/${tx.id}'),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$shortId',
                          style: AppTypography.titleMd.copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
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
                      '${formatTime(tx.clientCreatedAt)}  ·  ${paymentMethodLabel(tx.paymentMethod)}',
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupiah(tx.total),
                    style: AppTypography.titleMd.copyWith(
                      color: voided
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      decoration: voided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSm.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Grouping ──────────────────────────────────────────────────────────────────

sealed class _Entry {
  const _Entry();
}

class _Header extends _Entry {
  const _Header(this.label);
  final String label;
}

class _Row extends _Entry {
  const _Row(this.tx);
  final TransactionRow tx;
}

List<_Entry> _groupByDate(List<TransactionRow> txns) {
  final out = <_Entry>[];
  String? lastKey;
  for (final tx in txns) {
    final key = _dateKey(tx.clientCreatedAt);
    if (key != lastKey) {
      out.add(_Header(_dateLabel(tx.clientCreatedAt)));
      lastKey = key;
    }
    out.add(_Row(tx));
  }
  return out;
}

String _dateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

String _dateLabel(DateTime dt) {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  if (_sameDay(dt, today)) return 'Hari ini';
  if (_sameDay(dt, yesterday)) return 'Kemarin';
  return formatDate(dt);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
