import '../../l10n/generated/app_localizations.dart';
import '../domain/enums.dart';

String localizedPaymentMethodLabel(AppL10n l10n, PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => l10n.paymentCash,
    PaymentMethod.qris => l10n.paymentQris,
    PaymentMethod.debit => l10n.paymentDebit,
    PaymentMethod.credit => l10n.paymentCredit,
    PaymentMethod.transfer => l10n.paymentTransfer,
    PaymentMethod.other => l10n.paymentOther,
  };
}

String localizedTransactionStatusLabel(
  AppL10n l10n,
  TransactionStatus status,
) {
  return switch (status) {
    TransactionStatus.completed => l10n.transactionsStatusCompleted,
    TransactionStatus.voided => l10n.transactionsStatusVoided,
  };
}
