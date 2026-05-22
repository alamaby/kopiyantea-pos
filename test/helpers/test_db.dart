import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';

/// Default test IDs used across the test suite. Keep these in sync with
/// whatever the focused test expects, or pass overrides via [seedMinimal].
abstract class TestIds {
  static const branch = 'b1';
  static const branch2 = 'b2';
  static const user = 'u1';
  static const product = 'p1';
  static const inventoryItem = 'inv-milk';
  static const recipe = 'rec-1';
}

/// Minimal fixture covering the data graph needed by checkout-adjacent tests:
/// branch + cashier + product + branch_product + inventory_item + recipe.
///
/// Tax-related fields stay at column defaults (taxPercentage = 10 exclusive
/// per branches table default).
Future<void> seedMinimal(
  AppDatabase db, {
  String branchId = TestIds.branch,
  String userId = TestIds.user,
  String productId = TestIds.product,
  String inventoryItemId = TestIds.inventoryItem,
  String recipeId = TestIds.recipe,
  double basePrice = 25000,
  double recipeQty = 50,
  double cachedStock = 1000,
}) async {
  final now = DateTime(2026, 5, 20, 10);
  await db.into(db.branches).insert(BranchesCompanion.insert(
        id: branchId,
        name: 'Cabang Tes',
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.appUsers).insert(AppUsersCompanion.insert(
        id: userId,
        fullName: 'Kasir Tes',
        globalRole: GlobalRole.cashier,
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.userBranchAccesses).insert(UserBranchAccessesCompanion.insert(
        userId: userId,
        branchId: branchId,
        roleAtBranch: const Value(BranchRole.cashier),
      ));
  await db.into(db.products).insert(ProductsCompanion.insert(
        id: productId,
        name: 'Latte',
        basePrice: basePrice,
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.branchProducts).insert(BranchProductsCompanion.insert(
        productId: productId,
        branchId: branchId,
      ));
  await db.into(db.inventoryItems).insert(InventoryItemsCompanion.insert(
        id: inventoryItemId,
        branchId: branchId,
        name: 'Susu',
        unit: StockUnit.ml,
        cachedStock: Value(cachedStock),
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.productRecipes).insert(ProductRecipesCompanion.insert(
        id: recipeId,
        productId: productId,
        branchId: branchId,
        inventoryItemId: inventoryItemId,
        quantityRequired: recipeQty,
      ));
}

/// Convenience: returns the seeded branch row.
Future<BranchRow> branchRow(AppDatabase db,
        [String id = TestIds.branch]) =>
    (db.select(db.branches)..where((b) => b.id.equals(id))).getSingle();

/// Convenience: returns the seeded product row.
Future<ProductRow> productRow(AppDatabase db,
        [String id = TestIds.product]) =>
    (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();

/// Convenience: returns the seeded branch_product row.
Future<BranchProductRow> branchProductRow(
  AppDatabase db, {
  String branchId = TestIds.branch,
  String productId = TestIds.product,
}) =>
    (db.select(db.branchProducts)
          ..where((bp) =>
              bp.productId.equals(productId) & bp.branchId.equals(branchId)))
        .getSingle();
