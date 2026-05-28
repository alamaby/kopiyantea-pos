import 'dart:async';

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
import '../../core/utils/transaction_numbers.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../customers/customer_providers.dart';
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
                      .copyWith(color: context.colors.textSecondary),
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

class _TransactionList extends ConsumerStatefulWidget {
  const _TransactionList({required this.branchId});

  final String branchId;

  @override
  ConsumerState<_TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends ConsumerState<_TransactionList> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(branchTransactionsProvider(widget.branchId));
    final customersMap = <String, String>{
      for (final c in (ref.watch(allCustomersProvider).valueOrNull ??
          const <CustomerRow>[]))
        c.id: c.name,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari #ID, pelanggan, total, metode bayar',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Bersihkan',
                      onPressed: _clear,
                    ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusLg,
              ),
            ),
          ),
        ),
        Expanded(
          child: txAsync.when(
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
                  message:
                      'Transaksi yang Anda buat di Kasir akan muncul di sini.',
                );
              }
              final filtered = _query.isEmpty
                  ? txns
                  : txns
                      .where((tx) => _matchesQuery(
                            tx: tx,
                            query: _query,
                            customerNameById: customersMap,
                          ))
                      .toList();
              if (filtered.isEmpty) {
                return AppEmptyState(
                  title: 'Tidak ditemukan',
                  icon: Icons.search_off,
                  message:
                      'Tidak ada transaksi cocok dengan "${_searchCtrl.text}".',
                );
              }
              final entries = _groupByDate(filtered);
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
          ),
        ),
      ],
    );
  }
}

/// ENH-005 — pure matcher for client-side search. Case-insensitive contains
/// over: short ID (first 8 chars), total (raw integer string), payment
/// method label, and customer name resolved via [customerNameById].
bool _matchesQuery({
  required TransactionRow tx,
  required String query,
  required Map<String, String> customerNameById,
}) {
  final q = query.toLowerCase().replaceAll('#', '').trim();
  if (q.isEmpty) return true;

  final transactionNumber = displayTransactionRowNumber(tx).toLowerCase();
  if (transactionNumber.contains(q)) return true;

  final shortId = shortTransactionId(tx.id).toLowerCase();
  if (shortId.contains(q)) return true;

  if (tx.total.toStringAsFixed(0).contains(q)) return true;

  if (paymentMethodLabel(tx.paymentMethod).toLowerCase().contains(q)) {
    return true;
  }

  final cId = tx.customerId;
  if (cId != null) {
    final name = customerNameById[cId];
    if (name != null && name.toLowerCase().contains(q)) return true;
  }
  return false;
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final TransactionRow tx;

  @override
  Widget build(BuildContext context) {
    final transactionNumber = displayTransactionRowNumber(tx);
    final voided = tx.status == TransactionStatus.voided;

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => context.push('/transactions/${tx.id}'),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
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
                          '#$transactionNumber',
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
                          .copyWith(color: context.colors.textSecondary),
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
                          ? context.colors.textTertiary
                          : context.colors.textPrimary,
                      decoration: voided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.colors.textTertiary,
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
          color: context.colors.textSecondary,
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
