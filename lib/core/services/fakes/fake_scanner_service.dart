import 'dart:async';

import '../scanner_service.dart';

/// Dev/test fake — emits a canned scan value after a short delay.
class FakeScannerService implements ScannerService {
  final _controller = StreamController<String>.broadcast();

  /// Manually inject a scan result (for tests / dev tooling).
  void injectScan(String value) => _controller.add(value);

  @override
  Stream<String> scan() => _controller.stream;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> dispose() => _controller.close();
}
