import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';
import '../../core/pricing/pricing.dart';
import '../../core/services/printer_service.dart';
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
  static final Map<String, Uint8List> _imageCache = {};

  Future<bool> sharePaymentReceiptImage(
    String transactionId, {
    Rect? sharePositionOrigin,
  }) async {
    final payload = await _buildPaymentReceiptPayload(transactionId);
    if (payload == null || payload.items.isEmpty) return false;
    final transactionNumber = displayTransactionNumber(
      id: payload.transactionId,
      transactionNumber: payload.transactionNumber,
    );

    await _shareReceiptAsImage(
      payload: payload,
      subject: 'Struk #$transactionNumber',
      filePrefix: 'struk-$transactionNumber',
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<bool> shareBillReceiptImage({
    required CartState cart,
    required TotalsResult totals,
    Rect? sharePositionOrigin,
  }) async {
    final payload = await _buildBillReceiptPayload(cart: cart, totals: totals);
    if (payload == null || payload.items.isEmpty) return false;
    final transactionNumber = displayTransactionNumber(
      id: payload.transactionId,
      transactionNumber: payload.transactionNumber,
    );

    await _shareReceiptAsImage(
      payload: payload,
      subject: 'Tagihan #$transactionNumber',
      filePrefix: 'tagihan-$transactionNumber',
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<ReceiptPayload?> _buildPaymentReceiptPayload(
    String transactionId,
  ) async {
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
    final logoBytes = await _maybeFetchLogo(setting);
    final printQris = setting?.printQrisOnReceipt ?? false;
    final qrisBytes = (printQris &&
            tx.paymentMethod == PaymentMethod.qris &&
            branch.qrisImageUrl != null &&
            branch.qrisImageUrl!.isNotEmpty)
        ? await _fetchCached(branch.qrisImageUrl!)
        : null;
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

    return ReceiptPayload(
      transactionId: tx.id,
      transactionNumber: transactionNumber,
      timestamp: tx.clientCreatedAt,
      branchName: branch.name,
      branchAddress: branch.address,
      branchPhone: branch.phone,
      showBranchName: setting?.showBranchName ?? true,
      items: items
          .map(
            (it) => ReceiptItem(
              name: it.nameSnapshot,
              quantity: it.quantity,
              priceSnapshot: it.priceSnapshot,
              subtotal: it.subtotal,
              notes: it.notes,
              options: modifierFilter.transactionOptionLabels(
                optionsByItem[it.id],
              ),
            ),
          )
          .toList(growable: false),
      subtotal: tx.subtotal,
      discountAmount: tx.discountAmount,
      taxLabel: tx.taxLabelSnapshot,
      taxAmount: tx.taxAmount,
      total: tx.total,
      paymentMethodLabel: paymentMethodLabel(tx.paymentMethod),
      paymentReceived: tx.paymentReceived,
      paymentChange: tx.paymentChange,
      customerName: customerLabel,
      loyaltyPointsEarned:
          showLoyaltyPoints && earnedPoints > 0 ? earnedPoints : null,
      loyaltyPointsBalance: showLoyaltyPoints ? customer?.loyaltyPoints : null,
      cashierName: cashierName,
      headerText: setting?.headerText,
      footerText: setting?.footerText,
      paperWidthMm: setting?.paperWidthMm ?? 58,
      logoBytes: logoBytes,
      logoPosition: setting?.logoPosition ?? 'top',
      bankAccountSnapshot: tx.bankAccountSnapshot,
      qrisImageBytes: qrisBytes,
    );
  }

  Future<ReceiptPayload?> _buildBillReceiptPayload({
    required CartState cart,
    required TotalsResult totals,
  }) async {
    final branch = cart.branch;
    if (branch == null || cart.items.isEmpty) return null;

    final setting = await _loadReceiptSetting(branch.id);
    final logoBytes = await _maybeFetchLogo(setting);
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

    return ReceiptPayload(
      transactionId: transactionNumber,
      transactionNumber: transactionNumber,
      timestamp: now,
      branchName: branch.name,
      branchAddress: branch.address,
      branchPhone: branch.phone,
      showBranchName: setting?.showBranchName ?? true,
      items: cart.items
          .map(
            (it) => ReceiptItem(
              name: it.branchProduct.customName ?? it.product.name,
              quantity: it.quantity.toDouble(),
              priceSnapshot: it.effectiveUnitPrice,
              subtotal: it.lineSubtotal,
              notes: it.notes,
              options: modifierFilter.cartOptionLabels(it.selectedOptions),
            ),
          )
          .toList(growable: false),
      subtotal: totals.subtotal,
      discountAmount: cart.manualDiscountAmount,
      taxLabel: branch.taxLabel,
      taxAmount: totals.taxAmount,
      total: totals.total,
      paymentMethodLabel: 'Tagihan',
      customerName: customerLabel,
      cashierName: cashierName,
      headerText: setting?.headerText,
      footerText: PrintReceiptUseCase.billingFooterText,
      paperWidthMm: setting?.paperWidthMm ?? 58,
      logoBytes: logoBytes,
      logoPosition: setting?.logoPosition ?? 'top',
    );
  }

  Future<void> _shareReceiptAsImage({
    required ReceiptPayload payload,
    required String subject,
    required String filePrefix,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await const _ReceiptImageRenderer().renderPng(payload);
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

  Future<Uint8List?> _maybeFetchLogo(ReceiptSettingRow? setting) async {
    if (setting == null || !setting.showLogo) return null;
    final url = setting.logoUrl;
    if (url == null || url.isEmpty) return null;
    return _fetchCached(url);
  }

  Future<Uint8List?> _fetchCached(String url) async {
    if (_imageCache.containsKey(url)) return _imageCache[url];
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      _imageCache[url] = bytes;
      return bytes;
    } catch (_) {
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

class _ReceiptImageRenderer {
  const _ReceiptImageRenderer();

  static const Color _background = Color(0xFFE5E7EB);
  static const Color _paper = Colors.white;
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  Future<Uint8List> renderPng(ReceiptPayload payload) async {
    final logo = payload.logoBytes == null
        ? null
        : await _decodeImage(payload.logoBytes!);
    final qris = payload.qrisImageBytes == null
        ? null
        : await _decodeImage(payload.qrisImageBytes!);
    final layout = _ReceiptImageLayout(payload, logo, qris);
    final height = layout.measure().ceil();
    final width = layout.width.toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    layout.paint(canvas, height.toDouble());
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Gagal membuat gambar struk');
    return data.buffer.asUint8List();
  }

  static Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}

class _ReceiptImageLayout {
  _ReceiptImageLayout(this.payload, this.logo, this.qris);

  final ReceiptPayload payload;
  final ui.Image? logo;
  final ui.Image? qris;

  late Canvas _canvas;
  var _hasCanvas = false;
  var _y = 0.0;

  double get width => payload.paperWidthMm == 80 ? 900 : 720;
  double get _paperInset => 24;
  double get _padding => payload.paperWidthMm == 80 ? 56 : 44;
  double get _contentWidth => width - (_padding * 2);
  double get _lineGap => 6;
  double get _sectionGap => 14;
  int get _footerChars => payload.paperWidthMm == 80 ? 46 : 30;

  double measure() {
    _hasCanvas = false;
    _y = _padding;
    _layout();
    return _y + _padding;
  }

  void paint(Canvas canvas, double height) {
    _canvas = canvas;
    _hasCanvas = true;
    _y = _padding;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = _ReceiptImageRenderer._background,
    );
    final paperRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _paperInset,
        _paperInset,
        width - (_paperInset * 2),
        height - (_paperInset * 2),
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(paperRect, Paint()..color = _ReceiptImageRenderer._paper);
    _layout();
  }

  void _layout() {
    if (payload.logoPosition == 'top') _logo();
    if (payload.showBranchName && payload.branchName.isNotEmpty) {
      _center(payload.branchName, _branchStyle);
    }
    _centerIfNotEmpty(payload.branchAddress);
    _centerIfNotEmpty(payload.branchPhone);
    _centerIfNotEmpty(payload.headerText);
    _separator();

    final transactionNumber = displayTransactionNumber(
      id: payload.transactionId,
      transactionNumber: payload.transactionNumber,
    );
    _row('No:', '#$transactionNumber');
    _row('Tanggal:', formatDateTime(payload.timestamp));
    _rowIfNotEmpty('Pelanggan:', payload.customerName);
    _rowIfNotEmpty('Kasir:', payload.cashierName);
    if (payload.loyaltyPointsEarned != null &&
        payload.loyaltyPointsEarned! > 0) {
      final value = payload.loyaltyPointsBalance == null
          ? '+${payload.loyaltyPointsEarned} poin'
          : '+${payload.loyaltyPointsEarned} / '
              '${payload.loyaltyPointsBalance} poin';
      _row('Poin:', value);
    }
    _separator();

    for (final item in payload.items) {
      _item(item);
    }
    _separator();

    _kv('Subtotal', formatRupiah(payload.subtotal));
    if (payload.discountAmount > 0) {
      _kv('Diskon', '-${formatRupiah(payload.discountAmount)}');
    }
    _kv('Pajak (${payload.taxLabel})', formatRupiah(payload.taxAmount));
    _separator();
    _kv(
      'TOTAL',
      formatRupiah(payload.total),
      style: _totalStyle,
      minHeight: 44,
    );
    _separator();

    _kv('Bayar', payload.paymentMethodLabel);
    if (payload.bankAccountSnapshot != null &&
        payload.bankAccountSnapshot!.isNotEmpty) {
      _textLines('  ${payload.bankAccountSnapshot!}', _compactStyle);
    }
    if (payload.paymentReceived != null) {
      _kv('Diterima', formatRupiah(payload.paymentReceived!));
    }
    if (payload.paymentChange != null && payload.paymentChange! > 0) {
      _kv('Kembalian', formatRupiah(payload.paymentChange!));
    }
    _qris();

    _spacer(_sectionGap);
    _center('Terima Kasih', _footerTitleStyle);
    _centerWrappedIfNotEmpty(payload.footerText, maxChars: _footerChars);
    if (payload.logoPosition == 'bottom') {
      _spacer(_sectionGap);
      _logo();
    }
  }

  void _item(ReceiptItem item) {
    final qty = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toString();
    _textLines('${item.name} x $qty', _bodyStyle);
    _kv(
      '  ${formatRupiah(item.priceSnapshot)}',
      formatRupiah(item.subtotal),
    );
    for (final option in item.options) {
      _textLines('  - $option', _compactStyle);
    }
    if (item.notes != null && item.notes!.isNotEmpty) {
      _textLines('  * ${item.notes}', _compactStyle);
    }
  }

  void _logo() {
    if (logo == null) return;
    _image(logo!, maxWidthRatio: 0.74, maxHeight: 160);
  }

  void _qris() {
    if (qris == null) return;
    _spacer(_sectionGap);
    _center('SCAN QRIS UNTUK BAYAR', _footerTitleStyle);
    _center('Masukkan nominal sesuai TOTAL di atas', _centerStyle);
    _image(qris!, maxWidthRatio: 0.58, maxHeight: 260);
  }

  void _image(
    ui.Image image, {
    required double maxWidthRatio,
    required double maxHeight,
  }) {
    final effectiveMaxWidth = _contentWidth * maxWidthRatio;
    final effectiveMaxHeight =
        payload.paperWidthMm == 80 ? maxHeight * 1.18 : maxHeight;
    final scale = math
        .min(
          effectiveMaxWidth / image.width,
          effectiveMaxHeight / image.height,
        )
        .toDouble();
    final drawScale = math.min(scale, 1.0);
    final drawWidth = image.width * drawScale;
    final drawHeight = image.height * drawScale;
    if (_hasCanvas) {
      final dst = Rect.fromLTWH(
        (width - drawWidth) / 2,
        _y,
        drawWidth,
        drawHeight,
      );
      _canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    _y += drawHeight + _sectionGap;
  }

  void _separator() {
    _spacer(4);
    final y = _y + 12;
    if (_hasCanvas) {
      final paint = Paint()
        ..color = _ReceiptImageRenderer._muted.withOpacity(0.55)
        ..strokeWidth = 2;
      _canvas.drawLine(
        Offset(_padding, y),
        Offset(width - _padding, y),
        paint,
      );
    }
    _y += 28;
  }

  void _rowIfNotEmpty(String label, String? value) {
    if (value == null || value.isEmpty) return;
    _row(label, value);
  }

  void _row(String label, String value) => _kv(label, value);

  void _kv(
    String label,
    String value, {
    TextStyle? style,
    double minHeight = 0,
  }) {
    final textStyle = style ?? _bodyStyle;
    final labelPainter = _painter(label, textStyle);
    final valuePainter = _painter(value, textStyle, textAlign: TextAlign.right);
    final labelWidth = _contentWidth * 0.44;
    final valueWidth = _contentWidth - labelWidth - 16;
    labelPainter.layout(maxWidth: labelWidth);
    valuePainter.layout(maxWidth: valueWidth);
    final height = math.max(
      minHeight,
      math.max(labelPainter.height, valuePainter.height),
    );

    if (_hasCanvas) {
      labelPainter.paint(_canvas, Offset(_padding, _y));
      valuePainter.paint(
        _canvas,
        Offset(width - _padding - valuePainter.width, _y),
      );
    }
    _y += height + _lineGap;
  }

  void _centerIfNotEmpty(String? text) {
    if (text == null || text.isEmpty) return;
    _centerWrappedIfNotEmpty(text);
  }

  void _centerWrappedIfNotEmpty(String? text, {int? maxChars}) {
    if (text == null || text.isEmpty) return;
    for (final line in _wrapText(text, maxChars: maxChars ?? _footerChars)) {
      _center(line, _centerStyle);
    }
  }

  void _center(String text, TextStyle style) {
    final painter = _painter(text, style, textAlign: TextAlign.center);
    painter.layout(maxWidth: _contentWidth);
    if (_hasCanvas) {
      painter.paint(_canvas, Offset((width - painter.width) / 2, _y));
    }
    _y += painter.height + _lineGap;
  }

  void _textLines(String text, TextStyle style) {
    final maxChars = payload.paperWidthMm == 80 ? 46 : 32;
    for (final line in _wrapText(text, maxChars: maxChars)) {
      final painter = _painter(line, style);
      painter.layout(maxWidth: _contentWidth);
      if (_hasCanvas) {
        painter.paint(_canvas, Offset(_padding, _y));
      }
      _y += painter.height + _lineGap;
    }
  }

  void _spacer(double height) {
    _y += height;
  }

  TextPainter _painter(
    String text,
    TextStyle style, {
    TextAlign textAlign = TextAlign.left,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );
  }

  static List<String> _wrapText(String text, {required int maxChars}) {
    final result = <String>[];
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final indent = RegExp(r'^\s*').stringMatch(rawLine) ?? '';
      final words = rawLine.trim().split(RegExp(r'\s+'));
      var line = '';
      for (final word in words.where((w) => w.isNotEmpty)) {
        if (line.isEmpty) {
          line = '$indent$word';
        } else if ('$line $word'.length <= maxChars) {
          line = '$line $word';
        } else {
          result.add(line);
          line = '$indent$word';
        }
        while (line.length > maxChars) {
          result.add(line.substring(0, maxChars));
          line = '$indent${line.substring(maxChars).trimLeft()}';
        }
      }
      if (line.isNotEmpty) result.add(line);
    }
    return result;
  }

  static const _fontFamily = 'monospace';
  static const _bodyStyle = TextStyle(
    color: _ReceiptImageRenderer._text,
    fontSize: 24,
    height: 1.18,
    fontFamily: _fontFamily,
  );
  static const _compactStyle = TextStyle(
    color: _ReceiptImageRenderer._text,
    fontSize: 22,
    height: 1.16,
    fontFamily: _fontFamily,
  );
  static const _centerStyle = TextStyle(
    color: _ReceiptImageRenderer._text,
    fontSize: 24,
    height: 1.18,
    fontFamily: _fontFamily,
  );
  static const _branchStyle = TextStyle(
    color: _ReceiptImageRenderer._text,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.12,
    fontFamily: _fontFamily,
  );
  static const _totalStyle = TextStyle(
    color: _ReceiptImageRenderer._text,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.14,
    fontFamily: _fontFamily,
  );
  static const _footerTitleStyle = TextStyle(
    color: _ReceiptImageRenderer._text,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.16,
    fontFamily: _fontFamily,
  );
}

final shareReceiptUseCaseProvider = Provider<ShareReceiptUseCase>(
  ShareReceiptUseCase.new,
);
