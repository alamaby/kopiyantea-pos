import 'package:drift/drift.dart';

import 'branch_tables.dart';

@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  RealColumn get basePrice => real()();
  TextColumn get sku => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BranchProductRow')
class BranchProducts extends Table {
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.cascade)();
  RealColumn get priceOverride => real().nullable()();
  BoolColumn get isAvailable =>
      boolean().withDefault(const Constant(true))();
  TextColumn get customName => text().nullable()();
  RealColumn get discountPercentage =>
      real().withDefault(const Constant(0.0))();
  DateTimeColumn get discountValidUntil => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {productId, branchId};
}
