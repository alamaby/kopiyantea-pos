/// Device integrity verdict from Play Integrity (Android) / App Attest (iOS).
/// See ADR-0010.
class IntegrityVerdict {
  const IntegrityVerdict({
    required this.isDeviceTrusted,
    required this.isAppRecognized,
    this.details,
  });

  final bool isDeviceTrusted;
  final bool isAppRecognized;
  final String? details;

  bool get isFullyTrusted => isDeviceTrusted && isAppRecognized;
}

/// Abstract device integrity attestation service (master prompt §10.3).
/// Concrete Android/iOS implementations in Phase 5.
///
/// Verdict is cached per session; call once per sensitive operation group,
/// not per individual request (ADR-0010).
abstract class DeviceIntegrityService {
  /// [nonce] must be fresh per attestation request — generated server-side.
  Future<IntegrityVerdict> attest({required String nonce});
}
