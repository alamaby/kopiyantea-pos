import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:logger/logger.dart';

/// Builds an [http.Client] that enforces SHA-256 certificate pinning against
/// the provided fingerprints. See ADR-0010 + master prompt §2.12.
///
/// Implementation strategy:
/// - [SecurityContext] is created with `withTrustedRoots: false`, so every
///   cert fails standard chain validation by default.
/// - [HttpClient.badCertificateCallback] then receives the leaf cert; we
///   SHA-256 the DER bytes and accept only when the fingerprint matches the
///   allowlist. This is real cert pinning at TLS handshake time.
///
/// When [fingerprints] is empty (dev/staging without explicit pins set),
/// returns a default [http.Client] — no pinning. `Env.validate()` enforces
/// non-empty fingerprints in production builds (master prompt §2.6).
http.Client buildPinnedHttpClient(List<String> fingerprints) {
  if (fingerprints.isEmpty) {
    return http.Client();
  }

  // Normalize: strip ':' and whitespace, uppercase. Accept both
  // 'AA:BB:...' and 'AABB...' input forms.
  final normalized = fingerprints
      .map(
        (f) => f
            .toUpperCase()
            .replaceAll(':', '')
            .replaceAll(' ', '')
            .replaceAll('\n', ''),
      )
      .toSet();

  final log = Logger();
  final ctx = SecurityContext(withTrustedRoots: false);
  final httpClient = HttpClient(context: ctx)
    ..badCertificateCallback = (cert, host, port) {
      final hex = sha256
          .convert(cert.der)
          .bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      final accepted = normalized.contains(hex);
      if (!accepted) {
        log.w('[Cert pinning] rejected $host:$port — sha256=$hex');
      }
      return accepted;
    };

  return IOClient(httpClient);
}
