import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/daos/catalog_dao.dart';
import '../../core/database/daos/dao_providers.dart';

part 'menu_provider.g.dart';

/// Reactive list of available products for the given branch — joins
/// `products` × `branch_products` and filters by `is_available`/`is_active`.
@riverpod
Stream<List<BranchProductWithProductRow>> menuProducts(
  MenuProductsRef ref,
  String branchId,
) {
  return ref.watch(catalogDaoProvider).watchAvailableProducts(branchId);
}

@riverpod
Stream<Map<String, double>> recommendedMenuSales(
  RecommendedMenuSalesRef ref,
  String branchId,
) {
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day)
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1));
  final start =
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  return ref.watch(transactionDaoProvider).watchSoldQuantityByProductInRange(
        branchId: branchId,
        start: start,
        end: end,
      );
}
