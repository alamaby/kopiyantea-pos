import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
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

  static final Logger _log = Logger();

  /// In-memory cache so reprinting in the same session doesn't re-download
  /// the logo. Keyed by URL — invalidated when owner uploads a new logo
  /// (new URL).
  static final Map<String, Uint8List> _logoCache = {};

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

    // FEAT-001 — fetch modifier snapshots for each item to render under
    // the line name on the receipt.
    final optionDao = _ref.read(optionDaoProvider);
    final optionsByItem = await optionDao.getSnapshotsForItems(
      items.map((i) => i.id).toList(),
    );

    // FEAT-014 — per-branch receipt template settings.
    final setting = await _loadReceiptSetting(tx.branchId);
    final logoBytes = await _maybeFetchLogo(setting);

    // FEAT-014b — cashier name lookup. Skipped when setting opts out
    // (`showCashierName == false`) or when the user row can't be
    // resolved (e.g. demo fallback id).
    final cashierName = setting?.showCashierName ?? true
        ? (await branchDao.getUserById(tx.cashierId))?.fullName
        : null;

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
                options: (optionsByItem[it.id] ?? const [])
                    .map((o) => o.priceDeltaSnapshot == 0
                        ? '${o.optionGroupNameSnapshot}: ${o.optionNameSnapshot}'
                        : '${o.optionGroupNameSnapshot}: ${o.optionNameSnapshot} (+${o.priceDeltaSnapshot.toStringAsFixed(0)})')
                    .toList(growable: false),
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
      cashierName: cashierName,
      headerText: setting?.headerText,
      footerText: setting?.footerText,
      paperWidthMm: setting?.paperWidthMm ?? 58,
      logoBytes: logoBytes,
      logoPosition: setting?.logoPosition ?? 'top',
      bankAccountSnapshot: tx.bankAccountSnapshot,
    );

    final printer = _ref.read(printerServiceProvider);
    return printer.printReceipt(payload);
  }

  Future<ReceiptSettingRow?> _loadReceiptSetting(String branchId) async {
    final db = _ref.read(databaseProvider);
    return (db.select(db.receiptSettings)
          ..where((s) => s.branchId.equals(branchId)))
        .getSingleOrNull();
  }

  Future<Uint8List?> _maybeFetchLogo(ReceiptSettingRow? setting) async {
    if (setting == null) return null;
    if (!setting.showLogo) return null;
    final url = setting.logoUrl;
    if (url == null || url.isEmpty) return null;
    if (_logoCache.containsKey(url)) return _logoCache[url];
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _log.w('[Print] logo fetch HTTP ${response.statusCode}: $url');
        return null;
      }
      final bytes = response.bodyBytes;
      _logoCache[url] = bytes;
      return bytes;
    } catch (e) {
      _log.w('[Print] logo fetch failed', error: e);
      return null;
    }
  }
}

final printReceiptUseCaseProvider = Provider<PrintReceiptUseCase>(
  PrintReceiptUseCase.new,
);
