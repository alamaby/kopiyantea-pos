import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/customer_point_ledger_table.dart';

part 'customer_point_ledger_dao.g.dart';

@DriftAccessor(tables: [CustomerPointLedgers])
class CustomerPointLedgerDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerPointLedgerDaoMixin {
  CustomerPointLedgerDao(super.db);

  Future<void> upsert(CustomerPointLedgersCompanion companion) =>
      into(customerPointLedgers).insertOnConflictUpdate(companion);

  Future<List<CustomerPointLedgerRow>> getForTransaction(
          String transactionId) =>
      (select(customerPointLedgers)
            ..where((l) => l.transactionId.equals(transactionId))
            ..orderBy([(l) => OrderingTerm.asc(l.createdAt)]))
          .get();

  Future<CustomerPointLedgerRow?> getForTransactionReason({
    required String transactionId,
    required String reason,
  }) =>
      (select(customerPointLedgers)
            ..where((l) => l.transactionId.equals(transactionId))
            ..where((l) => l.reason.equals(reason)))
          .getSingleOrNull();
}
