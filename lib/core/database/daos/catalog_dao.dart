import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/catalog_tables.dart';

part 'catalog_dao.g.dart';

/// Row bundling a [BranchProductRow] join with its parent [ProductRow].
class BranchProductWithProductRow {
  BranchProductWithProductRow({
    required this.product,
    required this.branchProduct,
  });
  final ProductRow product;
  final BranchProductRow branchProduct;
}

@DriftAccessor(tables: [Products, BranchProducts])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  /// Reactive stream of available products for POS menu.
  Stream<List<BranchProductWithProductRow>> watchAvailableProducts(
    String branchId,
  ) {
    final query = select(branchProducts).join([
      innerJoin(products, products.id.equalsExp(branchProducts.productId)),
    ])
      ..where(branchProducts.branchId.equals(branchId))
      ..where(branchProducts.isAvailable.equals(true))
      ..where(products.isActive.equals(true));

    return query.watch().map(
          (rows) => rows
              .map(
                (r) => BranchProductWithProductRow(
                  product: r.readTable(products),
                  branchProduct: r.readTable(branchProducts),
                ),
              )
              .toList(),
        );
  }

  /// Reactive stream of ALL branch-products for management (includes
  /// unavailable rows and inactive master products — those are hidden from
  /// POS via [watchAvailableProducts] but must be visible in the catalog
  /// screen to allow re-activation).
  Stream<List<BranchProductWithProductRow>> watchAllForBranch(String branchId) {
    final query = select(branchProducts).join([
      innerJoin(products, products.id.equalsExp(branchProducts.productId)),
    ])
      ..where(branchProducts.branchId.equals(branchId));
    return query.watch().map(
          (rows) => rows
              .map(
                (r) => BranchProductWithProductRow(
                  product: r.readTable(products),
                  branchProduct: r.readTable(branchProducts),
                ),
              )
              .toList(),
        );
  }

  Stream<ProductRow?> watchProductById(String id) =>
      (select(products)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<ProductRow?> getProductById(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<ProductRow?> getBySku(String sku) =>
      (select(products)..where((p) => p.sku.equals(sku))).getSingleOrNull();

  Stream<BranchProductRow?> watchBranchProductPair(
    String productId,
    String branchId,
  ) =>
      (select(branchProducts)
            ..where(
              (bp) =>
                  bp.productId.equals(productId) &
                  bp.branchId.equals(branchId),
            ))
          .watchSingleOrNull();

  /// Quick switch — toggles only `is_available` without touching other fields.
  Future<int> setBranchProductAvailability({
    required String productId,
    required String branchId,
    required bool isAvailable,
  }) =>
      (update(branchProducts)
            ..where(
              (bp) =>
                  bp.productId.equals(productId) &
                  bp.branchId.equals(branchId),
            ))
          .write(BranchProductsCompanion(isAvailable: Value(isAvailable)));

  Future<void> upsertProduct(ProductsCompanion companion) =>
      into(products).insertOnConflictUpdate(companion);

  Future<void> upsertBranchProduct(BranchProductsCompanion companion) =>
      into(branchProducts).insertOnConflictUpdate(companion);

  /// Partial update — preserves fields not in [patch].
  Future<int> updateProduct(String id, ProductsCompanion patch) =>
      (update(products)..where((p) => p.id.equals(id))).write(patch);

  Future<int> updateBranchProduct({
    required String productId,
    required String branchId,
    required BranchProductsCompanion patch,
  }) =>
      (update(branchProducts)
            ..where(
              (bp) =>
                  bp.productId.equals(productId) &
                  bp.branchId.equals(branchId),
            ))
          .write(patch);

  Future<BranchProductRow?> getBranchProduct(
    String productId,
    String branchId,
  ) =>
      (select(branchProducts)
            ..where(
              (bp) =>
                  bp.productId.equals(productId) &
                  bp.branchId.equals(branchId),
            ))
          .getSingleOrNull();
}
