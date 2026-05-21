import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';

part 'bank_account_providers.g.dart';

/// FEAT-015 — reactive list of all bank accounts (admin view).
@riverpod
Stream<List<BankAccountRow>> allBankAccounts(AllBankAccountsRef ref) {
  return ref.watch(bankAccountDaoProvider).watchAll();
}

/// FEAT-015 — reactive list of active accounts (checkout picker).
@riverpod
Stream<List<BankAccountRow>> activeBankAccounts(
  ActiveBankAccountsRef ref,
) {
  return ref.watch(bankAccountDaoProvider).watchActive();
}

/// Human-readable snapshot string used at checkout: "BCA 1234567890 -
/// John Doe". Kept centralized so receipt + report + tx snapshot all
/// agree on format.
String formatBankAccountSnapshot(BankAccountRow a) =>
    '${a.bankName} ${a.accountNumber} - ${a.accountHolder}';
