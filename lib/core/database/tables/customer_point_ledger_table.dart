import 'package:drift/drift.dart';

import 'customer_tables.dart';
import 'transaction_tables.dart';

@DataClassName('CustomerPointLedgerRow')
class CustomerPointLedgers extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();
  IntColumn get pointsDelta => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
