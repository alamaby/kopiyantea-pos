import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bluetooth_printer_service.dart';
import 'device_integrity_service.dart';
import 'escpos_receipt_builder.dart';
import 'fakes/fake_device_integrity_service.dart';
import 'fakes/fake_printer_service.dart';
import 'fakes/fake_scanner_service.dart';
import 'printer_service.dart';
import 'scanner_service.dart';

/// Service bindings.
///
/// On Android/iOS we wire the real Bluetooth thermal printer. Other targets
/// (desktop / web / tests) fall back to [FakePrinterService] so dev flow
/// keeps working without hardware.

bool get _isMobile {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// ESC/POS builder is async to load the default capability profile — exposed
/// as a FutureProvider; [printerServiceProvider] waits on it on first use.
final escPosReceiptBuilderProvider = FutureProvider<EscPosReceiptBuilder>(
  (_) => EscPosReceiptBuilder.create(),
);

final printerServiceProvider = Provider<PrinterService>((ref) {
  if (!_isMobile) {
    return FakePrinterService();
  }
  final builderAsync = ref.watch(escPosReceiptBuilderProvider);
  final builder = builderAsync.maybeWhen(
    data: (b) => b,
    orElse: () => null,
  );
  if (builder == null) {
    // Builder is loading or errored — temporarily fall back to fake so the
    // app doesn't crash. Once the builder loads, this provider re-evaluates
    // and returns the real service.
    return FakePrinterService();
  }
  return BluetoothPrinterService(builder);
});

final scannerServiceProvider = Provider<ScannerService>(
  (_) => FakeScannerService(),
);

final deviceIntegrityServiceProvider = Provider<DeviceIntegrityService>(
  (_) => const FakeDeviceIntegrityService(),
);
