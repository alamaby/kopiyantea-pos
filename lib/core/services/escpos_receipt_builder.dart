import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

import '../utils/formatters.dart';
import '../utils/transaction_numbers.dart';
import 'printer_service.dart';

/// Pure function: [ReceiptPayload] → ESC/POS byte stream for a thermal printer.
///
/// Kept side-effect-free so the same builder can target both real printers
/// (via [BluetoothPrinterService.writeBytes]) and previews / golden tests.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder(this._profile);

  final CapabilityProfile _profile;
  static const _normalStyle = PosStyles(fontType: PosFontType.fontA);
  static const _compactStyle = PosStyles(fontType: PosFontType.fontB);
  static const _centerStyle = PosStyles(
    align: PosAlign.center,
    fontType: PosFontType.fontA,
  );

  /// Factory — loads the default ESC/POS capability profile asynchronously.
  static Future<EscPosReceiptBuilder> create() async {
    final profile = await CapabilityProfile.load();
    return EscPosReceiptBuilder(profile);
  }

  List<int> build(ReceiptPayload p) {
    final paperSize = p.paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final g = Generator(paperSize, _profile);
    // `var` because `bytes += ...` desugars to `bytes = bytes + ...` —
    // List `+` returns a new list, requiring reassignment.
    var bytes = <int>[...g.reset()];

    // ── Logo (top) ──
    if (p.logoBytes != null && p.logoPosition == 'top') {
      final logoCmd = _renderLogo(g, p.logoBytes!, p.paperWidthMm);
      if (logoCmd != null) bytes += logoCmd;
    }

    // ── Header ──
    if (p.showBranchName && p.branchName.isNotEmpty) {
      bytes += g.text(
        p.branchName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          fontType: PosFontType.fontA,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    }
    if (p.branchAddress != null) {
      bytes += g.text(p.branchAddress!, styles: _centerStyle);
    }
    if (p.branchPhone != null) {
      bytes += g.text(p.branchPhone!, styles: _centerStyle);
    }
    if (p.headerText != null && p.headerText!.isNotEmpty) {
      bytes += g.text(p.headerText!, styles: _centerStyle);
    }
    bytes += _resetText(g);
    bytes += g.hr();

    // ── Transaction meta ──
    final transactionNumber = displayTransactionNumber(
      id: p.transactionId,
      transactionNumber: p.transactionNumber,
    );
    bytes += g.row([
      PosColumn(text: 'No:', width: 3, styles: _normalStyle),
      PosColumn(
        text: '#$transactionNumber',
        width: 9,
        styles: const PosStyles(
          align: PosAlign.right,
          fontType: PosFontType.fontA,
        ),
      ),
    ]);
    bytes += g.row([
      PosColumn(text: 'Tanggal:', width: 4, styles: _normalStyle),
      PosColumn(
        text: formatDateTime(p.timestamp),
        width: 8,
        styles: const PosStyles(
          align: PosAlign.right,
          fontType: PosFontType.fontA,
        ),
      ),
    ]);
    if (p.customerName != null) {
      bytes += g.row([
        PosColumn(text: 'Pelanggan:', width: 4, styles: _normalStyle),
        PosColumn(
          text: p.customerName!,
          width: 8,
          styles: const PosStyles(
            align: PosAlign.right,
            fontType: PosFontType.fontA,
          ),
        ),
      ]);
    }
    if (p.cashierName != null && p.cashierName!.isNotEmpty) {
      bytes += g.row([
        PosColumn(text: 'Kasir:', width: 3, styles: _normalStyle),
        PosColumn(
          text: p.cashierName!,
          width: 9,
          styles: const PosStyles(
            align: PosAlign.right,
            fontType: PosFontType.fontA,
          ),
        ),
      ]);
    }
    if (p.loyaltyPointsEarned != null && p.loyaltyPointsEarned! > 0) {
      final balance = p.loyaltyPointsBalance == null
          ? '+${p.loyaltyPointsEarned} poin'
          : '+${p.loyaltyPointsEarned} / ${p.loyaltyPointsBalance} poin';
      bytes += g.row([
        PosColumn(text: 'Poin:', width: 3, styles: _normalStyle),
        PosColumn(
          text: balance,
          width: 9,
          styles: const PosStyles(
            align: PosAlign.right,
            fontType: PosFontType.fontA,
          ),
        ),
      ]);
    }
    bytes += _resetText(g);
    bytes += g.hr();

    // ── Items ──
    for (final item in p.items) {
      final qty = item.quantity == item.quantity.roundToDouble()
          ? item.quantity.toStringAsFixed(0)
          : item.quantity.toString();
      bytes += g.text('${item.name} x $qty', styles: _normalStyle);
      bytes += g.row([
        PosColumn(
          text: '  ${formatRupiah(item.priceSnapshot)}',
          width: 6,
          styles: _normalStyle,
        ),
        PosColumn(
          text: formatRupiah(item.subtotal),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            fontType: PosFontType.fontA,
          ),
        ),
      ]);
      // FEAT-001 — modifier snapshot bullets under the line.
      for (final opt in item.options) {
        bytes += g.text('  - $opt', styles: _compactStyle);
      }
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes += g.text('  * ${item.notes}', styles: _compactStyle);
      }
      if (item.options.isNotEmpty ||
          (item.notes != null && item.notes!.isNotEmpty)) {
        bytes += _resetText(g);
      }
    }
    bytes += g.hr();

    // ── Totals ──
    bytes += _kv(g, 'Subtotal', formatRupiah(p.subtotal));
    if (p.discountAmount > 0) {
      bytes += _kv(g, 'Diskon', '-${formatRupiah(p.discountAmount)}');
    }
    bytes += _kv(g, 'Pajak (${p.taxLabel})', formatRupiah(p.taxAmount));
    bytes += g.hr();
    bytes += g.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(
          bold: true,
          fontType: PosFontType.fontA,
          height: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: formatRupiah(p.total),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          fontType: PosFontType.fontA,
          height: PosTextSize.size2,
        ),
      ),
    ]);
    bytes += _resetText(g);
    bytes += g.hr();

    // ── Payment ──
    bytes += _kv(g, 'Bayar', p.paymentMethodLabel);
    if (p.bankAccountSnapshot != null && p.bankAccountSnapshot!.isNotEmpty) {
      // FEAT-015 — show destination rekening below "Bayar: Transfer".
      // Snapshot may be long ("BCA 1234567890 - John Doe"), so render on
      // its own line rather than as a key/value row to avoid truncation.
      bytes += g.text('  ${p.bankAccountSnapshot!}', styles: _compactStyle);
      bytes += _resetText(g);
    }
    if (p.paymentReceived != null) {
      bytes += _kv(g, 'Diterima', formatRupiah(p.paymentReceived!));
    }
    if (p.paymentChange != null && p.paymentChange! > 0) {
      bytes += _kv(g, 'Kembalian', formatRupiah(p.paymentChange!));
    }

    // ── QRIS (ENH-004 — static QR on receipt) ──
    // Customer scans this and inputs nominal manually from the TOTAL
    // line above. No dynamic generation.
    if (p.qrisImageBytes != null) {
      bytes += g.feed(1);
      bytes += g.text(
        'SCAN QRIS UNTUK BAYAR',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          fontType: PosFontType.fontA,
        ),
      );
      bytes += g.text(
        'Masukkan nominal sesuai TOTAL di atas',
        styles: _centerStyle,
      );
      final qrCmd = _renderLogo(g, p.qrisImageBytes!, p.paperWidthMm);
      if (qrCmd != null) bytes += qrCmd;
      bytes += _resetText(g);
    }

    // ── Footer ──
    bytes += g.feed(1);
    bytes += g.text(
      'Terima Kasih',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        fontType: PosFontType.fontA,
      ),
    );
    if (p.footerText != null && p.footerText!.isNotEmpty) {
      for (final line in _wrapText(
        p.footerText!,
        maxChars: _footerCharsPerLine(p.paperWidthMm),
      )) {
        bytes += g.text(line, styles: _centerStyle);
      }
    }

    // ── Logo (bottom) ──
    if (p.logoBytes != null && p.logoPosition == 'bottom') {
      bytes += g.feed(1);
      final logoCmd = _renderLogo(g, p.logoBytes!, p.paperWidthMm);
      if (logoCmd != null) bytes += logoCmd;
    }

    bytes += g.feed(1);
    bytes += g.cut();

    return bytes;
  }

  /// Decode + downscale + push as raster image. Returns null when bytes
  /// can't be decoded (corrupt file) so the receipt still prints without
  /// the logo instead of failing the whole job.
  static List<int>? _renderLogo(
    Generator g,
    Uint8List bytes,
    int paperWidthMm,
  ) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      // 58mm ≈ 384px printable, 80mm ≈ 576px. Downscale if wider so we
      // don't truncate / waste paper. Preserve aspect.
      final maxWidth = paperWidthMm == 80 ? 576 : 384;
      final resized = decoded.width > maxWidth
          ? img.copyResize(decoded, width: maxWidth)
          : decoded;
      return g.image(resized);
    } catch (_) {
      return null;
    }
  }

  static List<int> _kv(Generator g, String label, String value) => g.row([
        PosColumn(text: label, width: 6, styles: _normalStyle),
        PosColumn(
          text: value,
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            fontType: PosFontType.fontA,
          ),
        ),
      ]);

  static List<int> _resetText(Generator g) => g.setStyles(_normalStyle);

  static int _footerCharsPerLine(int paperWidthMm) =>
      paperWidthMm == 80 ? 46 : 30;

  static List<String> _wrapText(String text, {required int maxChars}) {
    final result = <String>[];
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final words = rawLine.trim().split(RegExp(r'\s+'));
      var line = '';
      for (final word in words.where((w) => w.isNotEmpty)) {
        if (line.isEmpty) {
          line = word;
        } else if ('$line $word'.length <= maxChars) {
          line = '$line $word';
        } else {
          result.add(line);
          line = word;
        }
        while (line.length > maxChars) {
          result.add(line.substring(0, maxChars));
          line = line.substring(maxChars);
        }
      }
      if (line.isNotEmpty) result.add(line);
    }
    return result;
  }
}
