import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../app_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [OutboxItems])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// Reactive count of pending items — drives the UI sync indicator.
  Stream<int> watchPendingCount() {
    final countExpr = outboxItems.id.count();
    final query = selectOnly(outboxItems)
      ..addColumns([countExpr])
      ..where(
        outboxItems.status.equalsValue(OutboxStatus.pending) |
            outboxItems.status.equalsValue(OutboxStatus.failed),
      );
    return query
        .map((row) => row.read(countExpr) ?? 0)
        .watchSingle();
  }

  Future<List<OutboxItemRow>> getPendingItems({int limit = 20}) =>
      (select(outboxItems)
            ..where(
              (o) =>
                  o.status.equalsValue(OutboxStatus.pending) |
                  o.status.equalsValue(OutboxStatus.failed),
            )
            ..where(
              (o) =>
                  o.nextRetryAt.isNull() |
                  o.nextRetryAt.isSmallerOrEqualValue(DateTime.now()),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
            ..limit(limit))
          .get();

  Future<void> enqueue(OutboxItemsCompanion companion) =>
      into(outboxItems).insert(companion);

  Future<void> markDone(String id) => (update(outboxItems)
        ..where((o) => o.id.equals(id)))
      .write(
        OutboxItemsCompanion(
          status: Value(OutboxStatus.done),
        ),
      );

  /// FEAT-003 — list everything for the Outbox Queue screen.
  Stream<List<OutboxItemRow>> watchAll() =>
      (select(outboxItems)..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .watch();

  /// FEAT-003 — clear a row from the queue (lossy if status != done).
  Future<int> deleteById(String id) =>
      (delete(outboxItems)..where((o) => o.id.equals(id))).go();

  /// FEAT-003 — reset a failed row to pending so it pushes on the next sync.
  Future<void> retryNow(String id) =>
      (update(outboxItems)..where((o) => o.id.equals(id))).write(
        OutboxItemsCompanion(
          status: Value(OutboxStatus.pending),
          nextRetryAt: const Value(null),
          lastError: const Value(null),
        ),
      );

  /// FEAT-003 — bulk retry all failed rows.
  Future<int> retryAllFailed() =>
      (update(outboxItems)
            ..where((o) => o.status.equalsValue(OutboxStatus.failed)))
          .write(
        OutboxItemsCompanion(
          status: Value(OutboxStatus.pending),
          nextRetryAt: const Value(null),
          lastError: const Value(null),
        ),
      );

  Future<void> markFailed(
    String id, {
    required String error,
    required DateTime nextRetry,
  }) =>
      (update(outboxItems)..where((o) => o.id.equals(id))).write(
        OutboxItemsCompanion(
          status: Value(OutboxStatus.failed),
          lastError: Value(error),
          nextRetryAt: Value(nextRetry),
          attemptCount: const Value.absent(),
        ),
      );
}
