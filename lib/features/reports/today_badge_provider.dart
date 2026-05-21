import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/daos/dao_providers.dart';

part 'today_badge_provider.g.dart';

/// ENH-002 — snapshot powering the "Hari Ini" quick badge in Home/POS
/// app bars. Counts completed transactions and sums their totals for the
/// current calendar day on a specific branch.
class TodayBadgeStats {
  const TodayBadgeStats({
    required this.transactionCount,
    required this.totalRevenue,
  });

  final int transactionCount;
  final double totalRevenue;

  static const empty =
      TodayBadgeStats(transactionCount: 0, totalRevenue: 0);
}

/// Reactive today-stats for [branchId]. Re-emits whenever a transaction
/// row in scope is inserted/updated (Drift stream backing). Auto-rolls
/// over at local midnight via a one-shot [Timer] that invalidates self.
@riverpod
Stream<TodayBadgeStats> todayBadgeStats(
  TodayBadgeStatsRef ref,
  String branchId,
) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final endOfDay = start
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1));

  // Schedule a one-shot rebuild just past midnight so the window flips
  // to the new day even if no transactions land at that moment.
  final nextMidnight = start.add(const Duration(days: 1));
  final timer = Timer(
    nextMidnight.difference(now) + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);

  final dao = ref.watch(transactionDaoProvider);
  return dao
      .watchCompletedInRange(
        branchId: branchId,
        start: start,
        end: endOfDay,
      )
      .map((rows) {
    var revenue = 0.0;
    for (final tx in rows) {
      revenue += tx.total;
    }
    return TodayBadgeStats(
      transactionCount: rows.length,
      totalRevenue: revenue,
    );
  });
}
