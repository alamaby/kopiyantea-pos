import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/catalog_dao.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/inventory_dao.dart';

part 'catalog_providers.g.dart';

/// Reactive ALL branch-products for management — includes unavailable rows
/// and inactive master products. Distinct from `menuProductsProvider` (POS),
/// which filters by `is_available=true` AND `products.is_active=true`.
@riverpod
Stream<List<BranchProductWithProductRow>> branchMenuFull(
  BranchMenuFullRef ref,
  String branchId,
) {
  return ref.watch(catalogDaoProvider).watchAllForBranch(branchId);
}

/// Single master product — reactive.
@riverpod
Stream<ProductRow?> productById(ProductByIdRef ref, String id) {
  return ref.watch(catalogDaoProvider).watchProductById(id);
}

/// Single branch override — reactive.
@riverpod
Stream<BranchProductRow?> branchProductPair(
  BranchProductPairRef ref,
  String productId,
  String branchId,
) {
  return ref
      .watch(catalogDaoProvider)
      .watchBranchProductPair(productId, branchId);
}

/// Recipe ingredients for a product at a given branch — reactive.
///
/// These drive inventory deduction at checkout (ADR-0003). Each row binds
/// an inventory item + the qty consumed per unit of product sold.
@riverpod
Stream<List<RecipeWithItem>> productRecipes(
  ProductRecipesRef ref,
  String productId,
  String branchId,
) {
  return ref
      .watch(inventoryDaoProvider)
      .watchRecipesWithItemsForProduct(productId, branchId);
}
