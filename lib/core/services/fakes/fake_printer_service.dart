import 'package:logger/logger.dart';

import '../printer_service.dart';
import '../../utils/result.dart';

/// Dev/test fake — logs receipt lines instead of sending to hardware.
class FakePrinterService implements PrinterService {
  final _log = Logger();
  bool _connected = false;
  String? _connectedAddress;

  @override
  bool get isConnected => _connected;

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
  Future<Result<Unit, PrinterError>> printReceipt(ReceiptPayload payload) async {
    if (!_connected) return const Err(PrinterError.notConnected);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _log.i('[FakePrinter] Printing receipt ${payload.transactionId}');
    for (final line in payload.lines) {
      _log.d('  $line');
    }
    return Ok(Unit.instance);
  }
}
