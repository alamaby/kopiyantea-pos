import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';
import '../../core/pricing/pricing.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/service_providers.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/result.dart';
import '../auth/auth_provider.dart';
import 'cart_state.dart';

/// Fetches transaction + items + branch + customer from local DB, builds a
/// [ReceiptPayload], and forwards to the active [PrinterService].
///
/// Lives in the POS feature because the print trigger is the post-checkout
/// receipt summary. Independent of the actual printer impl (real or fake).
class PrintReceiptUseCase {
  PrintReceiptUseCase(this._ref);

  final Ref _ref;

  static final Logger _log = Logger();
  static const billingFooterText =
      'Struk ini hanyalah bukti tagihan, bukan bukti pembayaran yang sah.';

  /// In-memory cache so reprinting in the same session doesn't re-download
  /// the same image (logo, QRIS, etc.). Keyed by URL — implicitly
  /// invalidated when owner uploads a new image (different URL is issued).
  static final Map<String, Uint8List> _imageCache = {};

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

    // FEAT-014b — cashier name. Prefer the immutable snapshot (set on
    // every new tx); fall back to a live `app_users` lookup for legacy
    // pre-snapshot rows. Skipped entirely when setting opts out.
    final cashierName = setting?.showCashierName ?? true
        ? (tx.cashierNameSnapshot?.isNotEmpty ?? false
            ? tx.cashierNameSnapshot
            : (await branchDao.getUserById(tx.cashierId))?.fullName)
        : null;

    // ENH-004 — opt-in static QRIS image on receipt. Only fired when
    // (a) owner enabled in receipt settings, (b) tx paid via QRIS,
    // (c) branch has a QRIS image uploaded. Uses the same cached
    // fetch path as the logo.
    final printQris = setting?.printQrisOnReceipt ?? false;
    final qrisBytes = (printQris &&
            tx.paymentMethod == PaymentMethod.qris &&
            branch.qrisImageUrl != null &&
            branch.qrisImageUrl!.isNotEmpty)
        ? await _fetchCached(branch.qrisImageUrl!)
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
      qrisImageBytes: qrisBytes,
    );

    final printer = _ref.read(printerServiceProvider);
    return printer.printReceipt(payload);
  }

  /// Prints the current cart as a billing receipt without saving a
  /// transaction. Intended for asking payment from the customer before the
  /// checkout flow is finalized.
  Future<Result<Unit, PrinterError>> printBill({
    required CartState cart,
    required TotalsResult totals,
  }) async {
    final branch = cart.branch;
    if (branch == null || cart.items.isEmpty) {
      return const Err(PrinterError.printFailed);
    }

    final setting = await _loadReceiptSetting(branch.id);
    final logoBytes = await _maybeFetchLogo(setting);
    final cashierName = setting?.showCashierName ?? true
        ? _ref.read(currentUserProvider)?.fullName
        : null;

    final payload = ReceiptPayload(
      transactionId: const Uuid().v7(),
      timestamp: DateTime.now(),
      branchName: branch.name,
      branchAddress: branch.address,
      branchPhone: branch.phone,
      items: cart.items
          .map((it) => ReceiptItem(
                name: it.branchProduct.customName ?? it.product.name,
                quantity: it.quantity.toDouble(),
                priceSnapshot: it.effectiveUnitPrice,
                subtotal: it.lineSubtotal,
                notes: it.notes,
                options: it.selectedOptions
                    .map((o) => o.priceDelta == 0
                        ? '${o.groupName}: ${o.optionName}'
                        : '${o.groupName}: ${o.optionName} (+${o.priceDelta.toStringAsFixed(0)})')
                    .toList(growable: false),
              ))
          .toList(growable: false),
      subtotal: totals.subtotal,
      discountAmount: cart.manualDiscountAmount,
      taxLabel: branch.taxLabel,
      taxAmount: totals.taxAmount,
      total: totals.total,
      paymentMethodLabel: 'Tagihan',
      customerName: cart.customer?.name,
      cashierName: cashierName,
      headerText: setting?.headerText,
      footerText: billingFooterText,
      paperWidthMm: setting?.paperWidthMm ?? 58,
      logoBytes: logoBytes,
      logoPosition: setting?.logoPosition ?? 'top',
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
    return _fetchCached(url);
  }

  /// HTTP GET with in-memory caching. Returns null on any failure so the
  /// receipt still prints (without the image) rather than aborting.
  Future<Uint8List?> _fetchCached(String url) async {
    if (_imageCache.containsKey(url)) return _imageCache[url];
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _log.w('[Print] image fetch HTTP ${response.statusCode}: $url');
        return null;
      }
      final bytes = response.bodyBytes;
      _imageCache[url] = bytes;
      return bytes;
    } catch (e) {
      _log.w('[Print] image fetch failed: $url', error: e);
      return null;
    }
  }
}

final printReceiptUseCaseProvider = Provider<PrintReceiptUseCase>(
  PrintReceiptUseCase.new,
);
