import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/inventory_tables.dart';

part 'inventory_dao.g.dart';

@DriftAccessor(tables: [InventoryItems, InventoryMovements, ProductRecipes])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  Stream<List<InventoryItemRow>> watchItemsForBranch(String branchId) =>
      (select(inventoryItems)
            ..where((i) => i.branchId.equals(branchId))
            ..orderBy([(i) => OrderingTerm.asc(i.name)]))
          .watch();

  /// Items at or below minimum stock — used for low-stock badge.
  Stream<List<InventoryItemRow>> watchLowStockItems(String branchId) =>
      (select(inventoryItems)
            ..where(
              (i) =>
                  i.branchId.equals(branchId) &
                  i.cachedStock.isSmallerOrEqualValue(0),
            ))
          .watch();

  Future<void> upsertItem(InventoryItemsCompanion companion) =>
      into(inventoryItems).insertOnConflictUpdate(companion);

  /// Appends an inventory movement. Never updates cached_stock directly —
  /// that is reconciled by a server trigger on Supabase (ADR-0003).
  Future<void> insertMovement(InventoryMovementsCompanion companion) =>
      into(inventoryMovements).insert(companion);

  Future<List<InventoryMovementRow>> getMovementsForItem(
    String inventoryItemId, {
    int limit = 50,
  }) =>
      (select(inventoryMovements)
            ..where((m) => m.inventoryItemId.equals(inventoryItemId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
            ..limit(limit))
          .get();

  Future<List<ProductRecipeRow>> getRecipesForProduct(
    String productId,
    String branchId,
  ) =>
      (select(productRecipes)
            ..where(
              (r) =>
                  r.productId.equals(productId) &
                  r.branchId.equals(branchId),
            ))
          .get();
}
