import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';

part 'transaction_providers.g.dart';

/// Bundles a transaction header with its line items + modifier snapshots
/// (FEAT-001) for the detail screen.
class TransactionDetailData {
  const TransactionDetailData({
    required this.transaction,
    required this.items,
    required this.optionsByItemId,
  });
  final TransactionRow transaction;
  final List<TransactionItemRow> items;
  final Map<String, List<TransactionItemOptionRow>> optionsByItemId;
}

/// Reactive paginated list of transactions for the active branch.
@riverpod
Stream<List<TransactionRow>> branchTransactions(
  BranchTransactionsRef ref,
  String branchId,
) {
  return ref.watch(transactionDaoProvider).watchTransactionsForBranch(branchId);
}

/// Single transaction with its items. Future-based — transactions are
/// append-only so the data doesn't change after creation (status may change
/// on void; pull-to-refresh handles that).
@riverpod
Future<TransactionDetailData?> transactionDetail(
  TransactionDetailRef ref,
  String transactionId,
) async {
  final dao = ref.watch(transactionDaoProvider);
  final tx = await dao.getTransactionById(transactionId);
  if (tx == null) return null;
  final items = await dao.getItemsForTransaction(transactionId);
  final optionDao = ref.watch(optionDaoProvider);
  final options = await optionDao.getSnapshotsForItems(
    items.map((i) => i.id).toList(),
  );
  return TransactionDetailData(
    transaction: tx,
    items: items,
    optionsByItemId: options,
  );
}
