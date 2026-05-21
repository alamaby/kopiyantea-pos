import 'dart:typed_data';

import '../utils/result.dart';

/// One line on the printed receipt.
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.priceSnapshot,
    required this.subtotal,
    this.notes,
    this.options = const [],
  });

  final String name;
  final double quantity;
  final double priceSnapshot;
  final double subtotal;
  final String? notes;
  /// FEAT-001 — bullet list of selected modifier names. Empty when product
  /// has no modifiers.
  final List<String> options;
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
    this.cashierName,
    this.headerText,
    this.footerText,
    this.paperWidthMm = 58,
    this.logoBytes,
    this.logoPosition = 'top',
    this.bankAccountSnapshot,
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
  /// FEAT-014b — staff who processed this tx. Null when the receipt
  /// setting `showCashierName` is off, or when the lookup failed.
  final String? cashierName;
  /// FEAT-015 — destination bank account for transfer payments. Printed
  /// on the next line after "Bayar: Transfer" so the receipt records
  /// exactly which rekening received the money.
  final String? bankAccountSnapshot;
  final String? headerText;
  final String? footerText;
  final int paperWidthMm; // 58 or 80

  /// FEAT-014 — raw PNG/JPEG bytes of the branch's receipt logo. Null when
  /// branch hasn't uploaded one or `showLogo` is off. Decoding happens in
  /// the ESC/POS builder.
  final Uint8List? logoBytes;

  /// FEAT-014 — 'top' (above header text) or 'bottom' (below footer).
  final String logoPosition;
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
