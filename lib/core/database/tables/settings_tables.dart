import 'package:drift/drift.dart';

import 'branch_tables.dart';

@DataClassName('ReceiptSettingRow')
class ReceiptSettings extends Table {
  TextColumn get id => text()();
  TextColumn get branchId =>
      text().unique().references(Branches, #id)();
  TextColumn get headerText => text().nullable()();
  TextColumn get footerText => text().nullable()();
  TextColumn get logoUrl => text().nullable()();
  /// 'top' (default) or 'bottom'. Where the logo prints relative to header
  /// text. Added v7 for receipt template configurator.
  TextColumn get logoPosition =>
      text().withDefault(const Constant('top'))();
  IntColumn get paperWidthMm =>
      integer().withDefault(const Constant(58))();
  BoolColumn get showLogo =>
      boolean().withDefault(const Constant(false))();
  /// FEAT-014b — print "Kasir: Nama" in the meta section of the receipt.
  /// Default true so existing receipts gain accountability without owner
  /// opt-in. Can be disabled per-branch for businesses that don't want
  /// the cashier's name on the customer copy.
  BoolColumn get showCashierName =>
      boolean().withDefault(const Constant(true))();
  TextColumn get locale =>
      text().withDefault(const Constant('id_ID'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
