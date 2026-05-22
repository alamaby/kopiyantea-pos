import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'branch_tables.dart';
import 'catalog_tables.dart';
import 'customer_tables.dart';

@DataClassName('TransactionRow')
class Transactions extends Table {
  // UUID v7 — also serves as idempotency key (ADR-0001)
  TextColumn get id => text()();
  TextColumn get branchId =>
      text().references(Branches, #id)();
  TextColumn get cashierId =>
      text().references(AppUsers, #id)();
  /// Immutable snapshot of the cashier's full name at checkout time. Set
  /// on every new transaction; pre-migration legacy rows have NULL and
  /// fall back to a live `app_users.full_name` lookup in the UI.
  TextColumn get cashierNameSnapshot => text().nullable()();
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
  /// FEAT-015 — bank account chosen at checkout when paymentMethod=transfer.
  /// Null for cash/QRIS/etc. Foreign key without DB-level constraint so
  /// owner deleting a bank account doesn't break historical transactions.
  TextColumn get bankAccountId => text().nullable()();
  /// FEAT-015 — immutable snapshot ("BCA 1234567890 - John Doe") so
  /// receipts + reports stay accurate even if bank account is later edited
  /// or deleted. Always set in tandem with `bankAccountId`.
  TextColumn get bankAccountSnapshot => text().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime()();
  DateTimeColumn get serverReceivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TransactionItemRow')
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
