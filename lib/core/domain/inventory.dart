import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'inventory.freezed.dart';

@freezed
class InventoryItem with _$InventoryItem {
  const factory InventoryItem({
    required String id,
    required String branchId,
    required String name,
    required StockUnit unit,
    required double cachedStock,
    required double minStock,
    required double costPerUnit,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _InventoryItem;
}

@freezed
class InventoryMovement with _$InventoryMovement {
  const factory InventoryMovement({
    required String id,
    required String inventoryItemId,
    required String branchId,
    required MovementType movementType,
    required double deltaSigned,
    String? referenceId,
    String? notes,
    String? createdBy,
    required DateTime createdAt,
  }) = _InventoryMovement;
}

@freezed
class ProductRecipe with _$ProductRecipe {
  const factory ProductRecipe({
    required String id,
    required String productId,
    required String branchId,
    required String inventoryItemId,
    required double quantityRequired,
  }) = _ProductRecipe;
}
