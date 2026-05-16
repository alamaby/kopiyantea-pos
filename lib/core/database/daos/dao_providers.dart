import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database_provider.dart';
import 'branch_dao.dart';
import 'catalog_dao.dart';
import 'customer_dao.dart';
import 'inventory_dao.dart';
import 'outbox_dao.dart';
import 'transaction_dao.dart';

/// DAO instances are exposed via Riverpod (not via getters on [AppDatabase])
/// to avoid the circular import that would otherwise exist between the
/// database file and each DAO file.

final branchDaoProvider = Provider<BranchDao>(
  (ref) => BranchDao(ref.watch(databaseProvider)),
);

final catalogDaoProvider = Provider<CatalogDao>(
  (ref) => CatalogDao(ref.watch(databaseProvider)),
);

final inventoryDaoProvider = Provider<InventoryDao>(
  (ref) => InventoryDao(ref.watch(databaseProvider)),
);

final transactionDaoProvider = Provider<TransactionDao>(
  (ref) => TransactionDao(ref.watch(databaseProvider)),
);

final customerDaoProvider = Provider<CustomerDao>(
  (ref) => CustomerDao(ref.watch(databaseProvider)),
);

final outboxDaoProvider = Provider<OutboxDao>(
  (ref) => OutboxDao(ref.watch(databaseProvider)),
);
