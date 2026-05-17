import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';

part 'customer_providers.g.dart';

/// All customers — reactive. UI applies search filter client-side.
@riverpod
Stream<List<CustomerRow>> allCustomers(AllCustomersRef ref) {
  return ref.watch(customerDaoProvider).watchAll();
}

/// Single customer by id — reactive (updates when loyalty points change, etc.).
@riverpod
Stream<CustomerRow?> customerById(CustomerByIdRef ref, String id) {
  return ref.watch(customerDaoProvider).watchById(id);
}
