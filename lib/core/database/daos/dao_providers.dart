import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database_provider.dart';
import 'bank_account_dao.dart';
import 'branch_dao.dart';
import 'catalog_dao.dart';
import 'category_dao.dart';
import 'customer_dao.dart';
import 'held_order_dao.dart';
import 'inventory_dao.dart';
import 'option_dao.dart';
import 'outbox_dao.dart';
import 'shift_closing_dao.dart';
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

final categoryDaoProvider = Provider<CategoryDao>(
  (ref) => CategoryDao(ref.watch(databaseProvider)),
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

final optionDaoProvider = Provider<OptionDao>(
  (ref) => OptionDao(ref.watch(databaseProvider)),
);

final heldOrderDaoProvider = Provider<HeldOrderDao>(
  (ref) => HeldOrderDao(ref.watch(databaseProvider)),
);

final shiftClosingDaoProvider = Provider<ShiftClosingDao>(
  (ref) => ShiftClosingDao(ref.watch(databaseProvider)),
);

final bankAccountDaoProvider = Provider<BankAccountDao>(
  (ref) => BankAccountDao(ref.watch(databaseProvider)),
);
