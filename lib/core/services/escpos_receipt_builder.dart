import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../utils/formatters.dart';
import 'printer_service.dart';

/// Pure function: [ReceiptPayload] → ESC/POS byte stream for a thermal printer.
///
/// Kept side-effect-free so the same builder can target both real printers
/// (via [BluetoothPrinterService.writeBytes]) and previews / golden tests.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder(this._profile);

  final CapabilityProfile _profile;

  /// Factory — loads the default ESC/POS capability profile asynchronously.
  static Future<EscPosReceiptBuilder> create() async {
    final profile = await CapabilityProfile.load();
    return EscPosReceiptBuilder(profile);
  }

  List<int> build(ReceiptPayload p) {
    final paperSize =
        p.paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final g = Generator(paperSize, _profile);
    // `var` because `bytes += ...` desugars to `bytes = bytes + ...` —
    // List `+` returns a new list, requiring reassignment.
    var bytes = <int>[];

    // ── Header ──
    bytes += g.text(
      p.branchName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    if (p.branchAddress != null) {
      bytes += g.text(p.branchAddress!,
          styles: const PosStyles(align: PosAlign.center));
    }
    if (p.branchPhone != null) {
      bytes += g.text(p.branchPhone!,
          styles: const PosStyles(align: PosAlign.center));
    }
    if (p.headerText != null && p.headerText!.isNotEmpty) {
      bytes += g.text(p.headerText!,
          styles: const PosStyles(align: PosAlign.center));
    }
    bytes += g.hr();

    // ── Transaction meta ──
    final shortId = p.transactionId.substring(0, 8).toUpperCase();
    bytes += g.row([
      PosColumn(text: 'No:', width: 3),
      PosColumn(
        text: '#$shortId',
        width: 9,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += g.row([
      PosColumn(text: 'Tanggal:', width: 4),
      PosColumn(
        text: formatDateTime(p.timestamp),
        width: 8,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (p.customerName != null) {
      bytes += g.row([
        PosColumn(text: 'Pelanggan:', width: 4),
        PosColumn(
          text: p.customerName!,
          width: 8,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += g.hr();

    // ── Items ──
    for (final item in p.items) {
      final qty = item.quantity == item.quantity.roundToDouble()
          ? item.quantity.toStringAsFixed(0)
          : item.quantity.toString();
      bytes += g.text('${item.name} x $qty');
      bytes += g.row([
        PosColumn(
          text: '  ${formatRupiah(item.priceSnapshot)}',
          width: 6,
        ),
        PosColumn(
          text: formatRupiah(item.subtotal),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes += g.text('  * ${item.notes}',
            styles: const PosStyles(fontType: PosFontType.fontB));
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
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: formatRupiah(p.total),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    ]);
    bytes += g.hr();

    // ── Payment ──
    bytes += _kv(g, 'Bayar', p.paymentMethodLabel);
    if (p.paymentReceived != null) {
      bytes += _kv(g, 'Diterima', formatRupiah(p.paymentReceived!));
    }
    if (p.paymentChange != null && p.paymentChange! > 0) {
      bytes += _kv(g, 'Kembalian', formatRupiah(p.paymentChange!));
    }

    // ── Footer ──
    bytes += g.feed(1);
    bytes += g.text(
      'Terima Kasih',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    if (p.footerText != null && p.footerText!.isNotEmpty) {
      bytes += g.text(p.footerText!,
          styles: const PosStyles(align: PosAlign.center));
    }
    bytes += g.feed(2);
    bytes += g.cut();

    return bytes;
  }

  static List<int> _kv(Generator g, String label, String value) =>
      g.row([
        PosColumn(text: label, width: 6),
        PosColumn(
          text: value,
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
}
