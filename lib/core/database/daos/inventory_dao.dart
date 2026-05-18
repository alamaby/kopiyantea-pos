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

  Stream<InventoryItemRow?> watchItemById(String id) =>
      (select(inventoryItems)..where((i) => i.id.equals(id)))
          .watchSingleOrNull();

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

  /// Reactive variant — new sales/adjustments push new rows into the stream.
  Stream<List<InventoryMovementRow>> watchMovementsForItem(
    String inventoryItemId, {
    int limit = 50,
  }) =>
      (select(inventoryMovements)
            ..where((m) => m.inventoryItemId.equals(inventoryItemId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
            ..limit(limit))
          .watch();

  /// Reactive recipe list with inventory item info — used by the catalog
  /// "Komposisi" section. Returned ordered by ingredient name.
  Stream<List<RecipeWithItem>> watchRecipesWithItemsForProduct(
    String productId,
    String branchId,
  ) {
    final query = select(productRecipes).join([
      innerJoin(inventoryItems,
          inventoryItems.id.equalsExp(productRecipes.inventoryItemId)),
    ])
      ..where(productRecipes.productId.equals(productId) &
          productRecipes.branchId.equals(branchId))
      ..orderBy([OrderingTerm.asc(inventoryItems.name)]);
    return query.watch().map(
          (rows) => rows
              .map((r) => RecipeWithItem(
                    recipe: r.readTable(productRecipes),
                    item: r.readTable(inventoryItems),
                  ))
              .toList(),
        );
  }

  Future<void> insertRecipe(ProductRecipesCompanion companion) =>
      into(productRecipes).insert(companion);

  /// Used by sync pull — server-side recipes overwrite local on id conflict.
  Future<void> upsertRecipe(ProductRecipesCompanion companion) =>
      into(productRecipes).insertOnConflictUpdate(companion);

  Future<int> updateRecipeQuantity({
    required String recipeId,
    required double quantityRequired,
  }) =>
      (update(productRecipes)..where((r) => r.id.equals(recipeId))).write(
        ProductRecipesCompanion(quantityRequired: Value(quantityRequired)),
      );

  Future<int> deleteRecipe(String recipeId) =>
      (delete(productRecipes)..where((r) => r.id.equals(recipeId))).go();

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

/// Recipe row joined with its inventory item for UI display.
class RecipeWithItem {
  RecipeWithItem({required this.recipe, required this.item});
  final ProductRecipeRow recipe;
  final InventoryItemRow item;
}
