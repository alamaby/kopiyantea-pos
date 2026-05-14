import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'transaction.freezed.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id, // UUID v7 — also the idempotency key
    required String branchId,
    required String cashierId,
    String? customerId,

    // Financials
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double total,

    // Tax snapshot — immutable after creation
    required double taxPercentageSnapshot,
    required String taxLabelSnapshot,
    required bool taxInclusiveSnapshot,

    // Payment
    required PaymentMethod paymentMethod,
    double? paymentReceived,
    double? paymentChange,

    // Lifecycle
    required TransactionStatus status,
    String? voidedByTransactionId,
    String? voidReason,
    required DateTime clientCreatedAt,
    DateTime? serverReceivedAt,
  }) = _Transaction;
}

@freezed
class TransactionItem with _$TransactionItem {
  const factory TransactionItem({
    required String id,
    required String transactionId,
    required String productId,
    required String nameSnapshot,
    required double priceSnapshot, // effective unit price after LEVEL 2 discount
    required double quantity,
    required double subtotal, // qty × priceSnapshot
    String? notes,
  }) = _TransactionItem;
}
