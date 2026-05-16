import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'branch_tables.dart';
import 'catalog_tables.dart';

@DataClassName('InventoryItemRow')
class InventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get branchId =>
      text().references(Branches, #id)();
  TextColumn get name => text()();
  TextColumn get unit => text().map(
        const EnumNameConverter<StockUnit>(StockUnit.values),
      )();
  RealColumn get cachedStock =>
      real().withDefault(const Constant(0.0))();
  RealColumn get minStock => real().withDefault(const Constant(0.0))();
  RealColumn get costPerUnit =>
      real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InventoryMovementRow')
class InventoryMovements extends Table {
  TextColumn get id => text()();
  TextColumn get inventoryItemId =>
      text().references(InventoryItems, #id)();
  TextColumn get branchId =>
      text().references(Branches, #id)();
  TextColumn get movementType => text().map(
        const EnumNameConverter<MovementType>(MovementType.values),
      )();
  RealColumn get deltaSigned => real()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProductRecipeRow')
class ProductRecipes extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.cascade)();
  TextColumn get inventoryItemId =>
      text().references(InventoryItems, #id)();
  RealColumn get quantityRequired => real()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
