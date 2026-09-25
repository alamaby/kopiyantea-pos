import 'package:drift/drift.dart';

@DataClassName('CustomerRow')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable().unique()();
  TextColumn get email => text().nullable()();
  IntColumn get loyaltyPoints =>
      integer().withDefault(const Constant(0))();
  /// FEAT-002 — tenant boundary, nullable during migration then backfilled.
  TextColumn get organizationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
