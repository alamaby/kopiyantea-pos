import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';

part 'inventory_providers.g.dart';

/// Reactive list of inventory items for the active branch.
@riverpod
Stream<List<InventoryItemRow>> branchInventory(
  BranchInventoryRef ref,
  String branchId,
) {
  return ref.watch(inventoryDaoProvider).watchItemsForBranch(branchId);
}

/// Reactive single item — live updates when stock changes (via sales / adjustments).
@riverpod
Stream<InventoryItemRow?> inventoryItem(
  InventoryItemRef ref,
  String itemId,
) {
  return ref.watch(inventoryDaoProvider).watchItemById(itemId);
}

/// Reactive movement history (newest first).
@riverpod
Stream<List<InventoryMovementRow>> inventoryMovements(
  InventoryMovementsRef ref,
  String itemId,
) {
  return ref.watch(inventoryDaoProvider).watchMovementsForItem(itemId);
}
