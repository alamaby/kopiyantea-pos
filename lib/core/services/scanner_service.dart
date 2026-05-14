/// Abstract QR/barcode scanner service (master prompt §10.3).
/// Concrete implementation with mobile_scanner in Phase 5.
abstract class ScannerService {
  /// Emits scanned QR/barcode values. Close when done.
  Stream<String> scan();

  /// Returns true if permission was granted.
  Future<bool> requestPermission();

  Future<void> dispose();
}
