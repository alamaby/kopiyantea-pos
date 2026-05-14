import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'branch_tables.dart';
import 'catalog_tables.dart';
import 'customer_tables.dart';

class Transactions extends Table {
  // UUID v7 — also serves as idempotency key (ADR-0001)
  TextColumn get id => text()();
  TextColumn get branchId =>
      text().references(Branches, #id)();
  TextColumn get cashierId =>
      text().references(AppUsers, #id)();
  TextColumn get customerId =>
      text().nullable().references(Customers, #id)();

  // Financials
  RealColumn get subtotal => real()();
  RealColumn get discountAmount =>
      real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount =>
      real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();

  // Tax snapshot — immutable, receipts must stay accurate even if rate changes
  RealColumn get taxPercentageSnapshot => real()();
  TextColumn get taxLabelSnapshot => text()();
  BoolColumn get taxInclusiveSnapshot => boolean()();

  // Payment
  TextColumn get paymentMethod => text().map(
        const EnumNameConverter<PaymentMethod>(PaymentMethod.values),
      )();
  RealColumn get paymentReceived => real().nullable()();
  RealColumn get paymentChange => real().nullable()();

  // Lifecycle
  TextColumn get status => text().map(
        const EnumNameConverter<TransactionStatus>(TransactionStatus.values),
      )();
  TextColumn get voidedByTransactionId => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime()();
  DateTimeColumn get serverReceivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TransactionItems extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId =>
      text().references(Products, #id)();
  TextColumn get nameSnapshot => text()();
  RealColumn get priceSnapshot => real()(); // post LEVEL-2 discount
  RealColumn get quantity => real()();
  RealColumn get subtotal => real()(); // qty × priceSnapshot
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
