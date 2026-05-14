import '../device_integrity_service.dart';

/// Dev/test fake — always returns a trusted verdict.
/// Swap for platform implementations in Phase 5 (ADR-0010).
class FakeDeviceIntegrityService implements DeviceIntegrityService {
  const FakeDeviceIntegrityService({this.trusted = true});

  final bool trusted;

  @override
  Future<IntegrityVerdict> attest({required String nonce}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return IntegrityVerdict(
      isDeviceTrusted: trusted,
      isAppRecognized: trusted,
      details: trusted ? 'fake-trusted' : 'fake-untrusted',
    );
  }
}
