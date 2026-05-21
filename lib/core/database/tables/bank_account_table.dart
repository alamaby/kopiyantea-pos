import 'package:drift/drift.dart';

/// FEAT-015 — bank transfer accounts (global, owner-managed).
///
/// Single-tenant scope: shared across all branches. When the cashier picks
/// `PaymentMethod.transfer` at checkout, they must select one of these
/// rows — the chosen id + a snapshot of the row are stored on the
/// transaction so reports can attribute revenue per rekening and receipts
/// stay correct even if owner later edits/deletes the account.
@DataClassName('BankAccountRow')
class BankAccounts extends Table {
  TextColumn get id => text()(); // UUID v7
  TextColumn get bankName => text()(); // e.g. "BCA", "Mandiri"
  TextColumn get accountNumber => text()();
  TextColumn get accountHolder => text()();
  /// Lower = appears first in the picker. Set via drag-reorder in UI
  /// (manual entry as integer for MVP).
  IntColumn get displayOrder =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
