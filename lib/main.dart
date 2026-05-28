import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_lifecycle_listener.dart';
import 'core/config/env.dart';
import 'core/database/app_database.dart';
import 'core/database/daos/held_order_dao.dart';
import 'core/database/database_provider.dart';
import 'core/logging/app_logger.dart';
import 'core/network/pinned_http_client.dart';
import 'core/sync/background_sync.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'router.dart';

/// Application entry point.
///
/// Boot order (offline-first):
/// 1. Env validation — fail fast if config is broken (master prompt §2.6)
/// 2. intl date symbols + Drift DB (local cache; master data is pulled)
/// 3. Supabase.initialize — graceful: log on failure but don't block the app.
///    The local Drift DB is the source of truth; sync (Phase 6e) catches up later.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Global error handlers + production-gated logger (master prompt §11).
  AppLogger.init();
  FlutterError.onError = AppLogger.onFlutterError;
  PlatformDispatcher.instance.onError = AppLogger.onPlatformError;

  final log = AppLogger.instance;

  // 1. Fail fast on missing / malformed env vars (ADR-0010, master prompt §2.6).
  try {
    Env.validate();
  } on StateError catch (e) {
    log.e('Env validation failed', error: e);
    runApp(_EnvErrorApp(message: e.message));
    return;
  }

  // 2. Local-first initialization — must succeed.
  await initializeDateFormatting('id_ID');
  final db = await AppDatabase.open();
  // SharedPreferences instance — touched here to surface any platform-channel
  // init errors early. Seed step was removed: first-time data is pulled from
  // Supabase via the post-login bootstrap flow (lib/features/auth/bootstrap_*).
  await SharedPreferences.getInstance();

  // FEAT-009 — drop held orders older than 24h so dine-in carts left over
  // from a previous shift don't litter the picker. Best-effort; failure
  // here should not block app launch.
  try {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final pruned = await HeldOrderDao(db).deleteOlderThan(cutoff);
    if (pruned > 0) log.i('Pruned $pruned stale held orders');
  } catch (e) {
    log.w('Held-order prune skipped', error: e);
  }

  // 3. Supabase — best-effort. App must boot even when offline / Supabase down.
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // SDK param name is historical; we feed our publishable key here.
      anonKey: Env.supabasePublishableKey,
      // Cert pinning (ADR-0010): when fingerprints are configured, every
      // HTTP request validates the TLS leaf against the allowlist. When
      // empty (dev), falls back to default http.Client.
      httpClient: buildPinnedHttpClient(Env.certFingerprints),
    );
    log.i('Supabase initialized for ${Env.appEnv} '
        '(pinning: ${Env.certFingerprints.isNotEmpty ? "on" : "off"})');
  } catch (e, st) {
    log.w(
      'Supabase init failed — running offline-only',
      error: e,
      stackTrace: st,
    );
  }

  // Phase 6 — OS-level best-effort sync. This complements the foreground
  // resume sync in AppResumeSyncListener and the manual Settings button.
  await initializeBackgroundSync();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const KopiyanteaPosApp(),
    ),
  );
}

class KopiyanteaPosApp extends ConsumerWidget {
  const KopiyanteaPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = _resolveThemeMode(ref);

    return AppResumeSyncListener(
      child: MaterialApp.router(
        title: 'KopiyanteaPOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('id', 'ID'),
      ),
    );
  }

  ThemeMode _resolveThemeMode(WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    return switch (settings?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

/// Fallback shown when env validation fails — gives the developer a clear
/// pointer instead of a black screen or generic crash.
class _EnvErrorApp extends StatelessWidget {
  const _EnvErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KopiyanteaPOS — Config Error',
      home: Scaffold(
        appBar: AppBar(title: const Text('Config Error')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Environment configuration is invalid.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Edit .env (see .env.example), then rebuild:\n'
                '  dart run build_runner build --delete-conflicting-outputs',
              ),
              const SizedBox(height: 16),
              SelectableText(message),
            ],
          ),
        ),
      ),
    );
  }
}
