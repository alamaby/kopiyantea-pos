import 'package:logger/logger.dart';

import '../../utils/formatters.dart';
import '../../utils/result.dart';
import '../../utils/transaction_numbers.dart';
import '../printer_service.dart';

/// Dev/test fake — logs the rendered receipt as plain text instead of writing
/// to a real printer. Useful on desktop / web / CI where no Bluetooth exists.
class FakePrinterService implements PrinterService {
  final _log = Logger();
  bool _connected = false;
  String? _connectedAddress;

  @override
  bool get isConnected => _connected;

  @override
  String? get connectedAddress => _connectedAddress;

  @override
  Future<List<PrinterDevice>> scanDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      PrinterDevice(address: '00:11:22:33:44:55', name: 'Fake Printer A'),
      PrinterDevice(address: 'AA:BB:CC:DD:EE:FF', name: 'Fake Printer B'),
    ];
  }

  @override
  Future<Result<Unit, PrinterError>> connect(String address) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _connected = true;
    _connectedAddress = address;
    _log.d('[FakePrinter] Connected to $address');
    return Ok(Unit.instance);
  }

  @override
  Future<Result<Unit, PrinterError>> disconnect() async {
    _connected = false;
    _log.d('[FakePrinter] Disconnected from $_connectedAddress');
    _connectedAddress = null;
    return Ok(Unit.instance);
  }

  @override
  Future<Result<Unit, PrinterError>> printReceipt(
    ReceiptPayload payload,
  ) async {
    if (!_connected) return const Err(PrinterError.notConnected);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _log.i('═══ FAKE RECEIPT ═══');
    _log.i(payload.branchName);
    if (payload.branchAddress != null) _log.i(payload.branchAddress);
    _log.i(
      '#${displayTransactionNumber(
        id: payload.transactionId,
        transactionNumber: payload.transactionNumber,
      )}',
    );
    _log.i(formatDateTime(payload.timestamp));
    if (payload.loyaltyPointsEarned != null &&
        payload.loyaltyPointsEarned! > 0) {
      _log.i(
        'Poin: +${payload.loyaltyPointsEarned}'
        '${payload.loyaltyPointsBalance == null ? '' : ' / ${payload.loyaltyPointsBalance}'}',
      );
    }
    for (final item in payload.items) {
      _log.i(
          '  ${item.name} × ${item.quantity}  ${formatRupiah(item.subtotal)}');
      if (item.notes != null && item.notes!.isNotEmpty) {
        _log.i('    note: ${item.notes}');
      }
    }
    _log.i('  Subtotal:  ${formatRupiah(payload.subtotal)}');
    if (payload.discountAmount > 0) {
      _log.i('  Diskon:    -${formatRupiah(payload.discountAmount)}');
    }
    _log.i('  Pajak (${payload.taxLabel}): ${formatRupiah(payload.taxAmount)}');
    _log.i('  TOTAL:     ${formatRupiah(payload.total)}');
    _log.i('  Bayar:     ${payload.paymentMethodLabel}');
    if (payload.paymentChange != null && payload.paymentChange! > 0) {
      _log.i('  Kembalian: ${formatRupiah(payload.paymentChange!)}');
    }
    _log.i('═══════════════════════');
    return Ok(Unit.instance);
  }
}
