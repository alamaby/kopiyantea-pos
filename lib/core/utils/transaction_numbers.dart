import '../database/app_database.dart';

String shortTransactionId(String id) => id.substring(0, 8).toUpperCase();

String displayTransactionNumber({
  required String id,
  String? transactionNumber,
}) {
  final number = transactionNumber?.trim();
  return number == null || number.isEmpty ? shortTransactionId(id) : number;
}

String displayTransactionRowNumber(TransactionRow tx) =>
    displayTransactionNumber(
      id: tx.id,
      transactionNumber: tx.transactionNumber,
    );
