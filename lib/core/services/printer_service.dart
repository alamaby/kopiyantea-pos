import '../utils/result.dart';

/// Receipt payload passed to the printer.
class ReceiptPayload {
  const ReceiptPayload({
    required this.transactionId,
    required this.lines,
    required this.paperWidthMm,
  });

  final String transactionId;
  final List<String> lines; // pre-rendered ESC/POS lines
  final int paperWidthMm;
}

class PrinterDevice {
  const PrinterDevice({required this.address, required this.name});
  final String address;
  final String name;
}

enum PrinterError { notConnected, printFailed, deviceNotFound, permissionDenied }

/// Abstract Bluetooth thermal printer service (ADR-0010, master prompt §10.3).
/// Concrete implementation in Phase 5.
abstract class PrinterService {
  Future<List<PrinterDevice>> scanDevices();
  Future<Result<Unit, PrinterError>> connect(String address);
  Future<Result<Unit, PrinterError>> disconnect();
  Future<Result<Unit, PrinterError>> printReceipt(ReceiptPayload payload);
  bool get isConnected;
}
