import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/catalog_tables.dart';

part 'catalog_dao.g.dart';

/// Row bundling a [BranchProduct] join with its parent [Product].
class BranchProductWithProduct {
  BranchProductWithProduct({required this.product, required this.branchProduct});
  final Product product;
  final BranchProduct branchProduct;
}

@DriftAccessor(tables: [Products, BranchProducts])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  /// Reactive stream of available products for POS menu.
  Stream<List<BranchProductWithProduct>> watchAvailableProducts(
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
                (r) => BranchProductWithProduct(
                  product: r.readTable(products),
                  branchProduct: r.readTable(branchProducts),
                ),
              )
              .toList(),
        );
  }

  Future<void> upsertProduct(ProductsCompanion companion) =>
      into(products).insertOnConflictUpdate(companion);

  Future<void> upsertBranchProduct(BranchProductsCompanion companion) =>
      into(branchProducts).insertOnConflictUpdate(companion);

  Future<BranchProduct?> getBranchProduct(
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
