import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
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
import '../settings/settings_provider.dart';
import 'cart_state.dart';

/// Fetches transaction + items + branch + customer from local DB, builds a
/// [ReceiptPayload], and forwards to the active [PrinterService].
///
/// Lives in the POS feature because the print trigger is the post-checkout
/// receipt summary. Independent of the actual printer impl (real or fake).
class PrintReceiptUseCase {
  PrintReceiptUseCase(this._ref);

  final Ref _ref;
  static const _kFallbackBillQueue = 0;

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
    final pointLedger = await _ref
        .read(customerPointLedgerDaoProvider)
        .getForTransaction(transactionId);
    final earnedPoints = pointLedger.fold<int>(
      0,
      (sum, row) => row.pointsDelta > 0 ? sum + row.pointsDelta : sum,
    );

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
      transactionNumber: tx.transactionNumber,
      timestamp: tx.clientCreatedAt,
      branchName: branch.name,
      branchAddress: branch.address,
      branchPhone: branch.phone,
      showBranchName: setting?.showBranchName ?? true,
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
      customerName: setting?.showCustomerName ?? true
          ? _customerReceiptLabel(
              name: customer?.name,
              phone: customer?.phone,
            )
          : null,
      loyaltyPointsEarned: earnedPoints > 0 ? earnedPoints : null,
      loyaltyPointsBalance: customer?.loyaltyPoints,
      cashierName: cashierName,
      headerText: setting?.headerText,
      footerText: setting?.footerText,
      paperWidthMm: setting?.paperWidthMm ?? 58,
      logoBytes: logoBytes,
      logoPosition: setting?.logoPosition ?? 'top',
      bankAccountSnapshot: tx.bankAccountSnapshot,
      qrisImageBytes: qrisBytes,
    );

    return _printWithAutoReconnect(payload);
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

    final now = DateTime.now();
    final transactionNumber = await _previewTransactionNumber(branch.id, now);

    final payload = ReceiptPayload(
      transactionId: const Uuid().v7(),
      transactionNumber: transactionNumber,
      timestamp: now,
      branchName: branch.name,
      branchAddress: branch.address,
      branchPhone: branch.phone,
      showBranchName: setting?.showBranchName ?? true,
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
      customerName: setting?.showCustomerName ?? true
          ? _customerReceiptLabel(
              name: cart.customer?.name,
              phone: cart.customer?.phone,
            )
          : null,
      cashierName: cashierName,
      headerText: setting?.headerText,
      footerText: billingFooterText,
      paperWidthMm: setting?.paperWidthMm ?? 58,
      logoBytes: logoBytes,
      logoPosition: setting?.logoPosition ?? 'top',
    );

    return _printWithAutoReconnect(payload);
  }

  Future<String> _previewTransactionNumber(
      String branchId, DateTime now) async {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final db = _ref.read(databaseProvider);
    final result = await db.customSelect(
      'SELECT COUNT(*) AS count FROM transactions '
      'WHERE branch_id = ? '
      'AND voided_by_transaction_id IS NULL '
      'AND client_created_at >= ? '
      'AND client_created_at < ?',
      variables: [
        Variable<String>(branchId),
        Variable<DateTime>(start),
        Variable<DateTime>(end),
      ],
    ).getSingleOrNull();
    final count = result?.read<int>('count') ?? _kFallbackBillQueue;
    return '${_two(now.year % 100)}${_two(now.month)}${_two(now.day)}'
        '${_two(now.hour)}${_two(now.minute)}-${(count + 1).toString().padLeft(3, '0')}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  Future<Result<Unit, PrinterError>> _printWithAutoReconnect(
    ReceiptPayload payload,
  ) async {
    final printer = _ref.read(printerServiceProvider);
    final savedAddress = await _lastPrinterAddress();
    final ready = await _ensureConnected(printer, savedAddress);
    if (ready is Err<Unit, PrinterError>) return ready;

    final result = await printer.printReceipt(payload);
    if (result case Err(error: PrinterError.notConnected)) {
      final reconnected = await _ensureConnected(
        printer,
        savedAddress,
        force: true,
      );
      if (reconnected is Err<Unit, PrinterError>) return reconnected;
      return printer.printReceipt(payload);
    }
    return result;
  }

  Future<Result<Unit, PrinterError>> _ensureConnected(
    PrinterService printer,
    String? savedAddress, {
    bool force = false,
  }) async {
    if (!force && printer.isConnected) return Ok(Unit.instance);
    if (savedAddress == null || savedAddress.isEmpty) {
      return const Err(PrinterError.notConnected);
    }
    return printer.connect(savedAddress);
  }

  Future<String?> _lastPrinterAddress() async {
    try {
      final settings = await _ref.read(settingsNotifierProvider.future);
      return settings.lastPrinterAddress;
    } catch (_) {
      return null;
    }
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

final printReceiptUseCaseProvider = Provider<PrintReceiptUseCase>(
  PrintReceiptUseCase.new,
);
