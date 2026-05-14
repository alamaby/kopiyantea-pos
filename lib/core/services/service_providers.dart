import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_integrity_service.dart';
import 'fakes/fake_device_integrity_service.dart';
import 'fakes/fake_printer_service.dart';
import 'fakes/fake_scanner_service.dart';
import 'printer_service.dart';
import 'scanner_service.dart';

/// Override these providers with concrete implementations in Phase 5.
/// In dev, the fakes are used by default.

final printerServiceProvider = Provider<PrinterService>(
  (_) => FakePrinterService(),
);

final scannerServiceProvider = Provider<ScannerService>(
  (_) => FakeScannerService(),
);

final deviceIntegrityServiceProvider = Provider<DeviceIntegrityService>(
  (_) => const FakeDeviceIntegrityService(),
);
