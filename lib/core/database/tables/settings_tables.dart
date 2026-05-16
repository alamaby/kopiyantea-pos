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
  IntColumn get paperWidthMm =>
      integer().withDefault(const Constant(58))();
  BoolColumn get showLogo =>
      boolean().withDefault(const Constant(false))();
  TextColumn get locale =>
      text().withDefault(const Constant('id_ID'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
