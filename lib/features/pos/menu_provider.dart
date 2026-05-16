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
