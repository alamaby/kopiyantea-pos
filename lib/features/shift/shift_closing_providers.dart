import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';

part 'shift_closing_providers.g.dart';

/// Aggregate of today's cash activity for a branch — drives the
/// expected-cash readout on [ShiftClosingScreen]. Snapshot read; refreshed
/// when the user lands on the screen.
class TodayCashSummary {
  const TodayCashSummary({
    required this.cashIn,
    required this.cashRefunded,
    required this.transactionCount,
    required this.refundCount,
  });
  final double cashIn;
  final double cashRefunded;
  final int transactionCount;
  final int refundCount;

  double get netCash => cashIn - cashRefunded;
}

@riverpod
Future<TodayCashSummary> todayCashSummary(
  TodayCashSummaryRef ref,
  String branchId,
) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);

  // Cash payments — completed + voided both with payment_method=cash. Void
  // rows have negative totals (ENH-008) so a simple SUM(total) nets refunds
  // automatically. We still report cashIn / cashRefunded separately for the
  // breakdown UI.
  final rows = await (db.select(db.transactions)
        ..where((t) =>
            t.branchId.equals(branchId) &
            t.paymentMethod.equalsValue(PaymentMethod.cash) &
            t.clientCreatedAt.isBetweenValues(start, now)))
      .get();

  double cashIn = 0;
  double cashRefunded = 0;
  int txCount = 0;
  int refundCount = 0;
  for (final tx in rows) {
    if (tx.status == TransactionStatus.voided) {
      cashRefunded += tx.total.abs();
      refundCount++;
    } else {
      cashIn += tx.total;
      txCount++;
    }
  }
  return TodayCashSummary(
    cashIn: cashIn,
    cashRefunded: cashRefunded,
    transactionCount: txCount,
    refundCount: refundCount,
  );
}

@riverpod
Stream<List<ShiftClosingRow>> shiftClosingHistory(
  ShiftClosingHistoryRef ref,
  String branchId,
) {
  return ref.watch(shiftClosingDaoProvider).watchForBranch(branchId);
}

/// Latest closing — used to default the opening float on the next day
/// (some shops carry over the prior counted cash as next-day float; we
/// just expose it for inspection).
@riverpod
Future<ShiftClosingRow?> latestShiftClosing(
  LatestShiftClosingRef ref,
  String branchId,
) {
  return ref.watch(shiftClosingDaoProvider).getLatestForBranch(branchId);
}

