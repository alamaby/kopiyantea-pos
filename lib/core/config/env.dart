import 'package:envied/envied.dart';

part 'env.g.dart';

/// Typed, compile-time environment configuration.
///
/// Values are baked in from `.env` at build time by `envied_generator`.
/// Run `dart run build_runner build` after editing `.env` to refresh `env.g.dart`.
///
/// `validate()` MUST be called from `main()` before any consumer reads a value,
/// to fail fast on missing / malformed configuration.
///
/// **About the publishable key:** Supabase introduced new API keys
/// (`sb_publishable_*`) to replace the legacy JWT `anon` key. They serve the
/// same purpose (public, RLS-protected, safe to ship to clients) but offer
/// per-key revocation/rotation. The supabase_flutter SDK still names its
/// parameter `anonKey:` — we feed our publishable key into it.
@Envied(path: '.env', requireEnvFile: true)
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL')
  static const String supabaseUrl = _Env.supabaseUrl;

  /// Supabase publishable key (`sb_publishable_...`). The legacy JWT anon key
  /// also works in this slot — the SDK forwards the string as-is.
  @EnviedField(varName: 'SUPABASE_PUBLISHABLE_KEY')
  static const String supabasePublishableKey = _Env.supabasePublishableKey;

  @EnviedField(varName: 'APP_ENV', defaultValue: 'development')
  static const String appEnv = _Env.appEnv;

  @EnviedField(varName: 'SUPABASE_CERT_FINGERPRINTS', defaultValue: '')
  static const String _certFingerprintsRaw = _Env._certFingerprintsRaw;

  static List<String> get certFingerprints => _certFingerprintsRaw
      .split(',')
      .map((f) => f.trim())
      .where((f) => f.isNotEmpty)
      .toList(growable: false);

  static bool get isProd => appEnv == 'production';
  static bool get isStaging => appEnv == 'staging';
  static bool get isDev => appEnv == 'development';

  /// Validates required env vars are present and well-formed.
  /// Throws [StateError] if anything is missing — main() should not catch this.
  static void validate() {
    final errors = <String>[];

    if (supabaseUrl.isEmpty) {
      errors.add('SUPABASE_URL is empty');
    } else if (!supabaseUrl.startsWith('https://')) {
      errors.add('SUPABASE_URL must start with https:// (got: $supabaseUrl)');
    }

    if (supabasePublishableKey.isEmpty) {
      errors.add('SUPABASE_PUBLISHABLE_KEY is empty');
    }

    if (!const {'development', 'staging', 'production'}.contains(appEnv)) {
      errors.add(
          'APP_ENV must be one of development|staging|production (got: $appEnv)');
    }

    if (isProd && certFingerprints.isEmpty) {
      errors.add('SUPABASE_CERT_FINGERPRINTS required in production');
    }

    if (errors.isNotEmpty) {
      throw StateError(
          'Invalid environment configuration:\n  - ${errors.join('\n  - ')}');
    }
  }
}
