import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/held_order_table.dart';

part 'held_order_dao.g.dart';

/// FEAT-009 — DAO for parked POS carts.
@DriftAccessor(tables: [HeldOrders])
class HeldOrderDao extends DatabaseAccessor<AppDatabase>
    with _$HeldOrderDaoMixin {
  HeldOrderDao(super.db);

  Stream<List<HeldOrderRow>> watchForBranch(String branchId) =>
      (select(heldOrders)
            ..where((h) => h.branchId.equals(branchId))
            ..orderBy([(h) => OrderingTerm.desc(h.createdAt)]))
          .watch();

  Future<HeldOrderRow?> getById(String id) =>
      (select(heldOrders)..where((h) => h.id.equals(id))).getSingleOrNull();

  Future<void> insert(HeldOrdersCompanion companion) =>
      into(heldOrders).insert(companion);

  Future<int> deleteById(String id) =>
      (delete(heldOrders)..where((h) => h.id.equals(id))).go();

  /// Removes held orders older than [cutoff]. Returns the number deleted.
  /// Called on app startup so dine-in carts left from previous shifts don't
  /// linger forever.
  Future<int> deleteOlderThan(DateTime cutoff) =>
      (delete(heldOrders)..where((h) => h.createdAt.isSmallerThanValue(cutoff)))
          .go();
}
