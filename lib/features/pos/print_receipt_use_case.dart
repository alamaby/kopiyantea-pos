import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/daos/dao_providers.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/service_providers.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/result.dart';

/// Fetches transaction + items + branch + customer from local DB, builds a
/// [ReceiptPayload], and forwards to the active [PrinterService].
///
/// Lives in the POS feature because the print trigger is the post-checkout
/// receipt summary. Independent of the actual printer impl (real or fake).
class PrintReceiptUseCase {
  PrintReceiptUseCase(this._ref);

  final Ref _ref;

  Future<Result<Unit, PrinterError>> print(String transactionId) async {
    final txDao = _ref.read(transactionDaoProvider);
    final branchDao = _ref.read(branchDaoProvider);
    final customerDao = _ref.read(customerDaoProvider);

    final tx = await txDao.getTransactionById(transactionId);
    if (tx == null) return const Err(PrinterError.printFailed);
    final items = await txDao.getItemsForTransaction(transactionId);
    final branch = await branchDao.getBranchById(tx.branchId);
    if (branch == null) return const Err(PrinterError.printFailed);
    final customer = tx.customerId == null
        ? null
        : await customerDao.getById(tx.customerId!);

    final payload = ReceiptPayload(
      transactionId: tx.id,
      timestamp: tx.clientCreatedAt,
      branchName: branch.name,
      branchAddress: branch.address,
      branchPhone: branch.phone,
      items: items
          .map((it) => ReceiptItem(
                name: it.nameSnapshot,
                quantity: it.quantity,
                priceSnapshot: it.priceSnapshot,
                subtotal: it.subtotal,
                notes: it.notes,
              ))
          .toList(growable: false),
      subtotal: tx.subtotal,
      discountAmount: tx.discountAmount,
      taxLabel: tx.taxLabelSnapshot,
      taxAmount: tx.taxAmount,
      total: tx.total,
      paymentMethodLabel: paymentMethodLabel(tx.paymentMethod),
      paymentReceived: tx.paymentReceived,
      paymentChange: tx.paymentChange,
      customerName: customer?.name,
    );

    final printer = _ref.read(printerServiceProvider);
    return printer.printReceipt(payload);
  }
}

final printReceiptUseCaseProvider = Provider<PrintReceiptUseCase>(
  PrintReceiptUseCase.new,
);
