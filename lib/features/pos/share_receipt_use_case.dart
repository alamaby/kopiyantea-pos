import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/pricing/pricing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/transaction_numbers.dart';
import '../auth/auth_provider.dart';
import 'cart_state.dart';
import 'print_receipt_use_case.dart';
import 'receipt_modifier_filter.dart';

class ShareReceiptUseCase {
  ShareReceiptUseCase(this._ref);

  final Ref _ref;

  Future<bool> sharePaymentReceiptImage(
    String transactionId, {
    Rect? sharePositionOrigin,
  }) async {
    final lines = await _buildPaymentReceiptLines(transactionId);
    if (lines == null || lines.isEmpty) return false;

    await _shareLinesAsImage(
      lines: lines,
      subject: 'Struk #${lines.transactionNumber}',
      filePrefix: 'struk-${lines.transactionNumber}',
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<bool> shareBillReceiptImage({
    required CartState cart,
    required TotalsResult totals,
    Rect? sharePositionOrigin,
  }) async {
    final lines = await _buildBillReceiptLines(cart: cart, totals: totals);
    if (lines == null || lines.isEmpty) return false;

    await _shareLinesAsImage(
      lines: lines,
      subject: 'Tagihan #${lines.transactionNumber}',
      filePrefix: 'tagihan-${lines.transactionNumber}',
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<_ReceiptLines?> _buildPaymentReceiptLines(String transactionId) async {
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
    final showLoyaltyPoints = setting?.showLoyaltyPoints ?? true;
    final earnedPoints = showLoyaltyPoints
        ? (await _ref
                .read(customerPointLedgerDaoProvider)
                .getForTransaction(transactionId))
            .fold<int>(
            0,
            (sum, row) => row.pointsDelta > 0 ? sum + row.pointsDelta : sum,
          )
        : 0;
    final optionsByItem = await optionDao.getSnapshotsForItems(
      items.map((i) => i.id).toList(),
    );
    final modifierFilter = await ReceiptModifierFilter.load(
      _ref.read(databaseProvider),
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
    final transactionNumber = displayTransactionRowNumber(tx);

    return _ReceiptLines(
      transactionNumber: transactionNumber,
      lines: [
        if (setting?.showBranchName ?? true) branch.name,
        if (branch.address?.isNotEmpty ?? false) branch.address!,
        if (branch.phone?.isNotEmpty ?? false) branch.phone!,
        if (setting?.headerText?.isNotEmpty ?? false) setting!.headerText!,
        _ReceiptImageRenderer.separator,
        'No: #$transactionNumber',
        'Tanggal: ${formatDateTime(tx.clientCreatedAt)}',
        if (customerLabel != null) 'Pelanggan: $customerLabel',
        if (cashierName?.isNotEmpty ?? false) 'Kasir: $cashierName',
        if (showLoyaltyPoints && earnedPoints > 0)
          'Poin: +$earnedPoints'
              '${customer == null ? '' : ' | Total Poin: ${customer.loyaltyPoints}'}',
        _ReceiptImageRenderer.separator,
        for (final item in items)
          ..._transactionItemLines(
            item,
            modifierFilter.transactionOptionLabels(optionsByItem[item.id]),
          ),
        _ReceiptImageRenderer.separator,
        'Subtotal: ${formatRupiah(tx.subtotal)}',
        if (tx.discountAmount > 0)
          'Diskon: -${formatRupiah(tx.discountAmount)}',
        if (tx.taxAmount > 0)
          'Pajak (${tx.taxLabelSnapshot}): ${formatRupiah(tx.taxAmount)}',
        'TOTAL: ${formatRupiah(tx.total)}',
        _ReceiptImageRenderer.separator,
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
      ],
    );
  }

  Future<_ReceiptLines?> _buildBillReceiptLines({
    required CartState cart,
    required TotalsResult totals,
  }) async {
    final branch = cart.branch;
    if (branch == null || cart.items.isEmpty) return null;

    final setting = await _loadReceiptSetting(branch.id);
    final modifierFilter = await ReceiptModifierFilter.load(
      _ref.read(databaseProvider),
    );
    final now = DateTime.now();
    final transactionNumber = await _previewTransactionNumber(branch.id, now);
    final cashierName = setting?.showCashierName ?? true
        ? _ref.read(currentUserProvider)?.fullName
        : null;
    final customerLabel = setting?.showCustomerName ?? true
        ? _customerReceiptLabel(
            name: cart.customer?.name,
            phone: cart.customer?.phone,
          )
        : null;

    return _ReceiptLines(
      transactionNumber: transactionNumber,
      lines: [
        if (setting?.showBranchName ?? true) branch.name,
        if (branch.address?.isNotEmpty ?? false) branch.address!,
        if (branch.phone?.isNotEmpty ?? false) branch.phone!,
        if (setting?.headerText?.isNotEmpty ?? false) setting!.headerText!,
        _ReceiptImageRenderer.separator,
        'TAGIHAN',
        'No: #$transactionNumber',
        'Tanggal: ${formatDateTime(now)}',
        if (customerLabel != null) 'Pelanggan: $customerLabel',
        if (cashierName?.isNotEmpty ?? false) 'Kasir: $cashierName',
        _ReceiptImageRenderer.separator,
        for (final item in cart.items)
          ..._cartItemLines(
            item,
            modifierFilter.cartOptionLabels(item.selectedOptions),
          ),
        _ReceiptImageRenderer.separator,
        'Subtotal: ${formatRupiah(totals.subtotal)}',
        if (cart.manualDiscountAmount > 0)
          'Diskon: -${formatRupiah(cart.manualDiscountAmount)}',
        if (totals.taxAmount > 0)
          'Pajak (${branch.taxLabel}): ${formatRupiah(totals.taxAmount)}',
        'TOTAL: ${formatRupiah(totals.total)}',
        _ReceiptImageRenderer.separator,
        PrintReceiptUseCase.billingFooterText,
        'Terima Kasih',
      ],
    );
  }

  Future<void> _shareLinesAsImage({
    required _ReceiptLines lines,
    required String subject,
    required String filePrefix,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await const _ReceiptImageRenderer().renderPng(lines.lines);
    final dir = await getTemporaryDirectory();
    final safePrefix = filePrefix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
    final fileName = '$safePrefix-${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png', name: fileName)],
      subject: subject,
      text: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  List<String> _transactionItemLines(
    TransactionItemRow item,
    List<String> options,
  ) {
    final qty = _formatQty(item.quantity);
    return [
      '${item.nameSnapshot} x $qty',
      '  ${formatRupiah(item.priceSnapshot)} = ${formatRupiah(item.subtotal)}',
      for (final option in options) '  - $option',
      if (item.notes?.isNotEmpty ?? false) '  * ${item.notes}',
    ];
  }

  List<String> _cartItemLines(CartItem item, List<String> options) {
    final qty = _formatQty(item.quantity.toDouble());
    return [
      '${item.branchProduct.customName ?? item.product.name} x $qty',
      '  ${formatRupiah(item.effectiveUnitPrice)} = ${formatRupiah(item.lineSubtotal)}',
      for (final option in options) '  - $option',
      if (item.notes?.isNotEmpty ?? false) '  * ${item.notes}',
    ];
  }

  String _formatQty(double quantity) => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toString();

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
    final count = result?.read<int>('count') ?? 0;
    return '${_two(now.year % 100)}${_two(now.month)}${_two(now.day)}'
        '${_two(now.hour)}${_two(now.minute)}-${(count + 1).toString().padLeft(3, '0')}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

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

class _ReceiptLines {
  const _ReceiptLines({
    required this.transactionNumber,
    required this.lines,
  });

  final String transactionNumber;
  final List<String> lines;

  bool get isEmpty => lines.isEmpty;
}

class _ReceiptImageRenderer {
  const _ReceiptImageRenderer();

  static const separator = '--------------------------------';
  static const double _width = 720;
  static const double _padding = 44;
  static const double _lineGap = 6;
  static const Color _background = Color(0xFFE5E7EB);
  static const Color _paper = Colors.white;
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  Future<Uint8List> renderPng(List<String> sourceLines) async {
    final lines = sourceLines.expand(_wrapLine).toList(growable: false);
    final height = _heightFor(lines).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paint(canvas, lines, height.toDouble());
    final image = await recorder.endRecording().toImage(_width.toInt(), height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Gagal membuat gambar struk');
    return data.buffer.asUint8List();
  }

  double _heightFor(List<String> lines) {
    var y = _padding;
    for (final line in lines) {
      y += _lineHeight(line) + _lineGap;
    }
    return y + _padding;
  }

  void _paint(Canvas canvas, List<String> lines, double height) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, height),
      Paint()..color = _background,
    );
    final paperRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(24, 24, _width - 48, height - 48),
      const Radius.circular(18),
    );
    canvas.drawRRect(paperRect, Paint()..color = _paper);

    var y = _padding;
    for (final line in lines) {
      final style = line == separator
          ? const TextStyle(
              color: _muted,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            )
          : const TextStyle(
              color: _text,
              fontSize: 24,
              height: 1.18,
              fontFamily: 'monospace',
            );
      final height = _drawText(canvas, line, y, style);
      y += height + _lineGap;
    }
  }

  Iterable<String> _wrapLine(String line) sync* {
    const maxChars = 38;
    final trimmedRight = line.trimRight();
    if (trimmedRight.isEmpty) {
      yield '';
      return;
    }
    if (trimmedRight == separator) {
      yield separator;
      return;
    }

    var remaining = trimmedRight;
    final indent = RegExp(r'^\s*').stringMatch(trimmedRight) ?? '';
    while (remaining.length > maxChars) {
      var cut = remaining.lastIndexOf(' ', maxChars);
      if (cut <= indent.length) cut = maxChars;
      yield remaining.substring(0, cut).trimRight();
      remaining = '$indent${remaining.substring(cut).trimLeft()}';
    }
    yield remaining;
  }

  double _lineHeight(String line) {
    final painter = TextPainter(
      text: TextSpan(
        text: line,
        style: const TextStyle(
          fontSize: 24,
          height: 1.18,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _width - (_padding * 2));
    return math.max(painter.height, 26);
  }

  double _drawText(Canvas canvas, String line, double y, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: line, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _width - (_padding * 2));
    painter.paint(canvas, Offset(_padding, y));
    return math.max(painter.height, 26);
  }
}

final shareReceiptUseCaseProvider = Provider<ShareReceiptUseCase>(
  ShareReceiptUseCase.new,
);
