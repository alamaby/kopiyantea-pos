import 'package:drift/drift.dart';

import 'catalog_tables.dart';
import 'transaction_tables.dart';

/// Product modifier system (FEAT-001).
///
/// Chain-wide design for MVP: option groups + options are global; the
/// product_option_groups junction binds them to products. Per-branch overrides
/// are deferred until a real need emerges.
///
/// At checkout time, the user's selected options are snapshotted into
/// transaction_item_options so receipts and audits stay accurate even if
/// the group/option master is later renamed or deleted.

@DataClassName('OptionGroupRow')
class OptionGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  BoolColumn get isMultiSelect =>
      boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('OptionRow')
class MenuOptions extends Table {
  // Drift would normally name the accessor `options` — that collides with
  // `GeneratedDatabase.options` (DriftDatabaseOptions). Class renamed to
  // `MenuOptions` (accessor → `menuOptions`), but the SQL table name stays
  // `options` so the Supabase migration matches.
  @override
  String get tableName => 'options';

  TextColumn get id => text()();
  TextColumn get groupId =>
      text().references(OptionGroups, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get priceDelta =>
      real().withDefault(const Constant(0.0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProductOptionGroupRow')
class ProductOptionGroups extends Table {
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get optionGroupId =>
      text().references(OptionGroups, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {productId, optionGroupId};
}

/// Snapshot of a single selected option attached to a transaction_item.
/// Snapshots are immutable — even if the master group/option is renamed
/// later, the receipt prints the original wording (master prompt §7.6 spirit).
@DataClassName('TransactionItemOptionRow')
class TransactionItemOptions extends Table {
  TextColumn get id => text()();
  TextColumn get transactionItemId =>
      text().references(TransactionItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get optionGroupNameSnapshot => text()();
  TextColumn get optionNameSnapshot => text()();
  RealColumn get priceDeltaSnapshot => real()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
