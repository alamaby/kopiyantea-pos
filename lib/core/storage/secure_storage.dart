import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around `flutter_secure_storage`.
///
/// Keys here are constants — never use raw strings at call sites so we can
/// audit what's stored in Keychain/Keystore from one place.
///
/// Master prompt §2.12: "Tokens in flutter_secure_storage." Do NOT use
/// SharedPreferences for auth tokens.
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  // ── Key constants ─────────────────────────────────────────────────────────

  static const String kSupabaseSession = 'auth.supabase_session';
  static const String kLastSignedInEmail = 'auth.last_email';

  // ── Generic ops ───────────────────────────────────────────────────────────

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clearAll() => _storage.deleteAll();
}
