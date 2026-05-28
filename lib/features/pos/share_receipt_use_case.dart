import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/transaction_numbers.dart';

class ShareReceiptUseCase {
  ShareReceiptUseCase(this._ref);

  final Ref _ref;

  Future<String?> buildText(String transactionId) async {
    final txDao = _ref.read(transactionDaoProvider);
    final branchDao = _ref.read(branchDaoProvider);
    final customerDao = _ref.read(customerDaoProvider);
    final optionDao = _ref.read(optionDaoProvider);

    final tx = await txDao.getTransactionById(transactionId);
    if (tx == null) return null;

    final items = await txDao.getItemsForTransaction(transactionId);
    final branch = await branchDao.getBranchById(tx.branchId);
    if (branch == null) return null;

    final customer = tx.customerId == null
        ? null
        : await customerDao.getById(tx.customerId!);
    final setting = await _loadReceiptSetting(tx.branchId);
    final optionsByItem = await optionDao.getSnapshotsForItems(
      items.map((i) => i.id).toList(),
    );

    final cashierName = setting?.showCashierName ?? true
        ? (tx.cashierNameSnapshot?.isNotEmpty ?? false
            ? tx.cashierNameSnapshot
            : (await branchDao.getUserById(tx.cashierId))?.fullName)
        : null;
    final customerLabel = setting?.showCustomerName ?? true
        ? _customerReceiptLabel(
            name: customer?.name,
            phone: customer?.phone,
          )
        : null;

    final lines = <String>[
      if (setting?.showBranchName ?? true) branch.name,
      if (branch.address?.isNotEmpty ?? false) branch.address!,
      if (branch.phone?.isNotEmpty ?? false) branch.phone!,
      if (setting?.headerText?.isNotEmpty ?? false) setting!.headerText!,
      '--------------------------------',
      'No: #${displayTransactionRowNumber(tx)}',
      'Tanggal: ${formatDateTime(tx.clientCreatedAt)}',
      if (customerLabel != null) 'Pelanggan: $customerLabel',
      if (cashierName?.isNotEmpty ?? false) 'Kasir: $cashierName',
      '--------------------------------',
      for (final item in items) ..._itemLines(item, optionsByItem[item.id]),
      '--------------------------------',
      'Subtotal: ${formatRupiah(tx.subtotal)}',
      if (tx.discountAmount > 0) 'Diskon: -${formatRupiah(tx.discountAmount)}',
      'Pajak (${tx.taxLabelSnapshot}): ${formatRupiah(tx.taxAmount)}',
      'TOTAL: ${formatRupiah(tx.total)}',
      '--------------------------------',
      'Bayar: ${paymentMethodLabel(tx.paymentMethod)}',
      if (tx.bankAccountSnapshot?.isNotEmpty ?? false)
        'Rekening: ${tx.bankAccountSnapshot}',
      if (tx.paymentReceived != null)
        'Diterima: ${formatRupiah(tx.paymentReceived!)}',
      if (tx.paymentChange != null && tx.paymentChange! > 0)
        'Kembalian: ${formatRupiah(tx.paymentChange!)}',
      '',
      if (setting?.footerText?.isNotEmpty ?? false) setting!.footerText!,
      'Terima Kasih',
    ];

    return lines.where((line) => line.trim().isNotEmpty).join('\n');
  }

  List<String> _itemLines(
    TransactionItemRow item,
    List<TransactionItemOptionRow>? options,
  ) {
    final qty = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toString();
    return [
      '${item.nameSnapshot} x $qty',
      '  ${formatRupiah(item.priceSnapshot)} = ${formatRupiah(item.subtotal)}',
      for (final option in options ?? const <TransactionItemOptionRow>[])
        option.priceDeltaSnapshot == 0
            ? '  - ${option.optionGroupNameSnapshot}: ${option.optionNameSnapshot}'
            : '  - ${option.optionGroupNameSnapshot}: ${option.optionNameSnapshot} (+${option.priceDeltaSnapshot.toStringAsFixed(0)})',
      if (item.notes?.isNotEmpty ?? false) '  * ${item.notes}',
    ];
  }

  Future<ReceiptSettingRow?> _loadReceiptSetting(String branchId) {
    final db = _ref.read(databaseProvider);
    return (db.select(db.receiptSettings)
          ..where((s) => s.branchId.equals(branchId)))
        .getSingleOrNull();
  }

  String? _customerReceiptLabel({
    required String? name,
    required String? phone,
  }) {
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return null;

    final maskedPhone = _maskedPhoneForReceipt(phone);
    if (maskedPhone == null) return trimmedName;
    return '$trimmedName ($maskedPhone)';
  }

  String? _maskedPhoneForReceipt(String? phone) {
    final digits = phone?.replaceAll(RegExp(r'\D'), '');
    if (digits == null || digits.isEmpty) return null;
    if (digits.length <= 6) return digits;

    final prefix = digits.substring(0, 3);
    final suffix = digits.substring(digits.length - 3);
    final mask = '*' * (digits.length - 6);
    return '$prefix$mask$suffix';
  }
}

final shareReceiptUseCaseProvider = Provider<ShareReceiptUseCase>(
  ShareReceiptUseCase.new,
);
