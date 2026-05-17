import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../utils/result.dart';
import 'escpos_receipt_builder.dart';
import 'printer_service.dart';

/// Real implementation backed by `print_bluetooth_thermal` (Android/iOS).
///
/// - Requires `BLUETOOTH_CONNECT` + `BLUETOOTH_SCAN` (Android 12+).
/// - Uses paired devices only — user must pair the printer via system
///   Bluetooth settings first.
/// - Connection state is in-memory; persisted printer address is in
///   `SettingsNotifier.lastPrinterAddress`.
class BluetoothPrinterService implements PrinterService {
  BluetoothPrinterService(this._builder);

  final EscPosReceiptBuilder _builder;
  final Logger _log = Logger();

  bool _connected = false;
  String? _address;

  @override
  bool get isConnected => _connected;

  @override
  String? get connectedAddress => _address;

  @override
  Future<List<PrinterDevice>> scanDevices() async {
    final granted = await _ensurePermissions();
    if (!granted) {
      _log.w('[BTPrinter] Bluetooth permission not granted');
      return const [];
    }
    final bluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;
    if (!bluetoothOn) {
      _log.w('[BTPrinter] Bluetooth is off');
      return const [];
    }
    final paired = await PrintBluetoothThermal.pairedBluetooths;
    return paired
        .map((d) => PrinterDevice(address: d.macAdress, name: d.name))
        .toList(growable: false);
  }

  @override
  Future<Result<Unit, PrinterError>> connect(String address) async {
    final granted = await _ensurePermissions();
    if (!granted) return const Err(PrinterError.permissionDenied);
    final bluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;
    if (!bluetoothOn) return const Err(PrinterError.bluetoothOff);

    try {
      final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      );
      if (!ok) {
        _log.w('[BTPrinter] connect($address) returned false');
        return const Err(PrinterError.deviceNotFound);
      }
      _connected = true;
      _address = address;
      return Ok(Unit.instance);
    } catch (e, st) {
      _log.e('[BTPrinter] connect failed', error: e, stackTrace: st);
      return const Err(PrinterError.printFailed);
    }
  }

  @override
  Future<Result<Unit, PrinterError>> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _connected = false;
      _address = null;
      return Ok(Unit.instance);
    } catch (e) {
      return const Err(PrinterError.printFailed);
    }
  }

  @override
  Future<Result<Unit, PrinterError>> printReceipt(
    ReceiptPayload payload,
  ) async {
    // Verify connection — package's writeBytes silently no-ops when not
    // connected, so we surface a typed error to the UI.
    final stillConnected = await PrintBluetoothThermal.connectionStatus;
    if (!stillConnected) {
      _connected = false;
      return const Err(PrinterError.notConnected);
    }

    try {
      final bytes = _builder.build(payload);
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      return ok ? Ok(Unit.instance) : const Err(PrinterError.printFailed);
    } catch (e, st) {
      _log.e('[BTPrinter] print failed', error: e, stackTrace: st);
      return const Err(PrinterError.printFailed);
    }
  }

  /// Requests Bluetooth permissions on Android 12+ (S+). Lower API versions
  /// fall through (permission_handler returns granted).
  Future<bool> _ensurePermissions() async {
    final scan = await Permission.bluetoothScan.request();
    if (scan.isPermanentlyDenied) return false;
    final connect = await Permission.bluetoothConnect.request();
    return scan.isGranted && connect.isGranted;
  }
}
