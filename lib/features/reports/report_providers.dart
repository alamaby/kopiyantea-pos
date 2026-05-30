import 'package:flutter/material.dart' show DateTimeRange;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../settings/branch_selection_provider.dart';

part 'report_providers.g.dart';

// ── Date presets ──────────────────────────────────────────────────────────────

enum DatePreset { today, yesterday, last7Days, last30Days }

extension DatePresetX on DatePreset {
  String get label => switch (this) {
        DatePreset.today => 'Hari Ini',
        DatePreset.yesterday => 'Kemarin',
        DatePreset.last7Days => '7 Hari',
        DatePreset.last30Days => '30 Hari',
      };

  DateTimeRange range(DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    return switch (this) {
      DatePreset.today => DateTimeRange(start: startOfToday, end: endOfToday),
      DatePreset.yesterday => DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 1)),
          end: endOfToday.subtract(const Duration(days: 1)),
        ),
      DatePreset.last7Days => DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 6)),
          end: endOfToday,
        ),
      DatePreset.last30Days => DateTimeRange(
          start: startOfToday.subtract(const Duration(days: 29)),
          end: endOfToday,
        ),
    };
  }
}

class ReportRangeSelection {
  const ReportRangeSelection._({
    required this.range,
    this.preset,
  });

  factory ReportRangeSelection.preset(DatePreset preset, DateTime now) =>
      ReportRangeSelection._(
        preset: preset,
        range: preset.range(now),
      );

  factory ReportRangeSelection.custom({
    required DateTime start,
    required DateTime end,
  }) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final firstDay = startDay.isAfter(endDay) ? endDay : startDay;
    final lastDay = startDay.isAfter(endDay) ? startDay : endDay;
    return ReportRangeSelection._(
      range: DateTimeRange(
        start: firstDay,
        end: lastDay
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1)),
      ),
    );
  }

  final DatePreset? preset;
  final DateTimeRange range;
}

// ── Report model ──────────────────────────────────────────────────────────────

class DailyReport {
  const DailyReport({
    required this.preset,
    required this.range,
    required this.transactionCount,
    required this.totalRevenue,
    required this.byPayment,
    required this.byBankAccount,
    required this.topItems,
  });

  final DatePreset? preset;
  final DateTimeRange range;
  final int transactionCount;
  final double totalRevenue;
  final Map<PaymentMethod, PaymentStats> byPayment;

  /// FEAT-015 — breakdown of `PaymentMethod.transfer` revenue per
  /// destination bank account. Keyed by snapshot string (e.g.
  /// "BCA 1234567890 - John") for stability across owner edits.
  final Map<String, PaymentStats> byBankAccount;
  final List<TopItem> topItems;

  double get averageOrderValue =>
      transactionCount > 0 ? totalRevenue / transactionCount : 0;
}

class PaymentStats {
  const PaymentStats({required this.count, required this.revenue});
  final int count;
  final double revenue;
}

class TopItem {
  const TopItem({
    required this.productId,
    required this.name,
    required this.totalQty,
    required this.totalRevenue,
  });

  final String productId;
  final String name;
  final double totalQty;
  final double totalRevenue;
}

// ── Pure aggregator ───────────────────────────────────────────────────────────

DailyReport buildReport({
  required DatePreset? preset,
  required DateTimeRange range,
  required List<TransactionRow> transactions,
  required List<TransactionItemRow> items,
}) {
  final byPayment = <PaymentMethod, PaymentStats>{};
  final byBankAccount = <String, PaymentStats>{};
  var totalRevenue = 0.0;

  for (final tx in transactions) {
    totalRevenue += tx.total;
    final existing = byPayment[tx.paymentMethod];
    byPayment[tx.paymentMethod] = PaymentStats(
      count: (existing?.count ?? 0) + 1,
      revenue: (existing?.revenue ?? 0) + tx.total,
    );
    // FEAT-015 — bucket transfers by destination bank.
    if (tx.paymentMethod == PaymentMethod.transfer) {
      final key = tx.bankAccountSnapshot ?? 'Tanpa rekening';
      final existingBank = byBankAccount[key];
      byBankAccount[key] = PaymentStats(
        count: (existingBank?.count ?? 0) + 1,
        revenue: (existingBank?.revenue ?? 0) + tx.total,
      );
    }
  }

  // Aggregate items by product
  final accByProduct = <String, _ItemAcc>{};
  for (final it in items) {
    final acc = accByProduct[it.productId] ??
        _ItemAcc(name: it.nameSnapshot, qty: 0, revenue: 0);
    accByProduct[it.productId] = _ItemAcc(
      name: acc.name,
      qty: acc.qty + it.quantity,
      revenue: acc.revenue + it.subtotal,
    );
  }

  final topItems = accByProduct.entries
      .map((e) => TopItem(
            productId: e.key,
            name: e.value.name,
            totalQty: e.value.qty,
            totalRevenue: e.value.revenue,
          ))
      .toList()
    ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

  return DailyReport(
    preset: preset,
    range: range,
    transactionCount: transactions.length,
    totalRevenue: totalRevenue,
    byPayment: byPayment,
    byBankAccount: byBankAccount,
    topItems: topItems.take(5).toList(),
  );
}

class _ItemAcc {
  const _ItemAcc({
    required this.name,
    required this.qty,
    required this.revenue,
  });
  final String name;
  final double qty;
  final double revenue;
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Selected date range preset. Notifier so the UI can flip it without
/// invalidating the report's dependencies graph.
@riverpod
class ReportRange extends _$ReportRange {
  @override
  ReportRangeSelection build() =>
      ReportRangeSelection.preset(DatePreset.today, DateTime.now());

  void setPreset(DatePreset preset) =>
      state = ReportRangeSelection.preset(preset, DateTime.now());

  void setCustom({required DateTime start, required DateTime end}) =>
      state = ReportRangeSelection.custom(start: start, end: end);
}

/// Daily summary for the active branch + selected preset.
/// Returns null when no branch is selected.
@riverpod
Future<DailyReport?> dailyReport(DailyReportRef ref) async {
  final branch = await ref.watch(selectedBranchProvider.future);
  if (branch == null) return null;
  final selection = ref.watch(reportRangeProvider);
  final range = selection.range;

  final dao = ref.watch(transactionDaoProvider);
  final txns = await dao.getCompletedInRange(
    branchId: branch.id,
    start: range.start,
    end: range.end,
  );
  final items =
      await dao.getItemsForTransactionIds(txns.map((t) => t.id).toList());

  return buildReport(
    preset: selection.preset,
    range: range,
    transactions: txns,
    items: items,
  );
}
