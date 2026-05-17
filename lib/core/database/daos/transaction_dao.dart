import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../app_database.dart';
import '../tables/transaction_tables.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions, TransactionItems])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  /// Reactive paginated stream of transactions for a branch.
  Stream<List<TransactionRow>> watchTransactionsForBranch(
    String branchId, {
    int limit = 50,
  }) =>
      (select(transactions)
            ..where((t) => t.branchId.equals(branchId))
            ..orderBy([(t) => OrderingTerm.desc(t.clientCreatedAt)])
            ..limit(limit))
          .watch();

  Future<TransactionRow?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// All completed transactions in [start..end] for the branch — used by
  /// the Reports aggregator. End is inclusive; pass end-of-day for daily reports.
  Future<List<TransactionRow>> getCompletedInRange({
    required String branchId,
    required DateTime start,
    required DateTime end,
  }) =>
      (select(transactions)
            ..where((t) =>
                t.branchId.equals(branchId) &
                t.status.equalsValue(TransactionStatus.completed) &
                t.clientCreatedAt.isBetweenValues(start, end))
            ..orderBy([(t) => OrderingTerm.asc(t.clientCreatedAt)]))
          .get();

  /// Fetches items for a batch of transaction ids — used by the Reports
  /// aggregator to compute top sellers without a join.
  Future<List<TransactionItemRow>> getItemsForTransactionIds(
    List<String> txIds,
  ) {
    if (txIds.isEmpty) return Future.value(const []);
    return (select(transactionItems)
          ..where((ti) => ti.transactionId.isIn(txIds)))
        .get();
  }

  Future<List<TransactionItemRow>> getItemsForTransaction(
    String transactionId,
  ) =>
      (select(transactionItems)
            ..where((ti) => ti.transactionId.equals(transactionId)))
          .get();

  /// Writes a transaction and its items atomically.
  /// The outbox entry is written in the same outer db.transaction() call
  /// from the use-case layer (ADR-0004).
  Future<void> insertTransactionWithItems(
    TransactionsCompanion txCompanion,
    List<TransactionItemsCompanion> itemCompanions,
  ) async {
    await into(transactions).insert(txCompanion);
    await batch((b) => b.insertAll(transactionItems, itemCompanions));
  }
}
