import '../utils/result.dart';

/// One line on the printed receipt.
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.priceSnapshot,
    required this.subtotal,
    this.notes,
  });

  final String name;
  final double quantity;
  final double priceSnapshot;
  final double subtotal;
  final String? notes;
}

/// Full data the printer needs to render a receipt.
///
/// Built from a saved transaction by [PrintReceiptUseCase] — the receipt
/// surface (UI button) only sees the transactionId; data assembly happens
/// in the use case so the printer service stays presentation-agnostic.
class ReceiptPayload {
  const ReceiptPayload({
    required this.transactionId,
    required this.timestamp,
    required this.branchName,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxLabel,
    required this.taxAmount,
    required this.total,
    required this.paymentMethodLabel,
    this.branchAddress,
    this.branchPhone,
    this.paymentReceived,
    this.paymentChange,
    this.customerName,
    this.headerText,
    this.footerText,
    this.paperWidthMm = 58,
  });

  final String transactionId;
  final DateTime timestamp;
  final String branchName;
  final String? branchAddress;
  final String? branchPhone;
  final List<ReceiptItem> items;
  final double subtotal;
  final double discountAmount;
  final String taxLabel;
  final double taxAmount;
  final double total;
  final String paymentMethodLabel; // human-readable: "Tunai", "QRIS", etc.
  final double? paymentReceived;
  final double? paymentChange;
  final String? customerName;
  final String? headerText;
  final String? footerText;
  final int paperWidthMm; // 58 or 80
}

class PrinterDevice {
  const PrinterDevice({required this.address, required this.name});
  final String address;
  final String name;
}

enum PrinterError {
  notConnected,
  printFailed,
  deviceNotFound,
  permissionDenied,
  bluetoothOff,
}

/// Abstract Bluetooth thermal printer service (ADR-0010, master prompt §10.3).
/// Concrete implementations:
/// - `BluetoothPrinterService` (mobile production) — wraps `print_bluetooth_thermal`
/// - `FakePrinterService` (dev / non-mobile) — logs receipt instead of printing
abstract class PrinterService {
  Future<List<PrinterDevice>> scanDevices();
  Future<Result<Unit, PrinterError>> connect(String address);
  Future<Result<Unit, PrinterError>> disconnect();
  Future<Result<Unit, PrinterError>> printReceipt(ReceiptPayload payload);
  bool get isConnected;
  String? get connectedAddress;
}
