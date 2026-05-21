import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/bank_account_table.dart';

part 'bank_account_dao.g.dart';

/// FEAT-015 — CRUD for global bank transfer accounts.
@DriftAccessor(tables: [BankAccounts])
class BankAccountDao extends DatabaseAccessor<AppDatabase>
    with _$BankAccountDaoMixin {
  BankAccountDao(super.db);

  /// Reactive list of ALL accounts (active + inactive) for the management
  /// screen.
  Stream<List<BankAccountRow>> watchAll() => (select(bankAccounts)
        ..orderBy([
          (a) => OrderingTerm.asc(a.displayOrder),
          (a) => OrderingTerm.asc(a.bankName),
        ]))
      .watch();

  /// Reactive active-only — drives the checkout picker.
  Stream<List<BankAccountRow>> watchActive() => (select(bankAccounts)
        ..where((a) => a.isActive.equals(true))
        ..orderBy([
          (a) => OrderingTerm.asc(a.displayOrder),
          (a) => OrderingTerm.asc(a.bankName),
        ]))
      .watch();

  Future<BankAccountRow?> getById(String id) =>
      (select(bankAccounts)..where((a) => a.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsert(BankAccountsCompanion companion) =>
      into(bankAccounts).insertOnConflictUpdate(companion);

  Future<int> updateById(String id, BankAccountsCompanion patch) =>
      (update(bankAccounts)..where((a) => a.id.equals(id))).write(patch);

  Future<int> deleteById(String id) =>
      (delete(bankAccounts)..where((a) => a.id.equals(id))).go();
}
