import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/database/seed_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'router.dart';

/// Application entry point.
///
/// Boot order (offline-first):
/// 1. Env validation — fail fast if config is broken (master prompt §2.6)
/// 2. intl date symbols + Drift DB + seed (works fully offline)
/// 3. Supabase.initialize — graceful: log on failure but don't block the app.
///    The local Drift DB is the source of truth; sync (Phase 6e) catches up later.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = Logger();

  // 1. Fail fast on missing / malformed env vars (ADR-0010, master prompt §2.6).
  try {
    Env.validate();
  } on StateError catch (e) {
    log.e('Env validation failed', error: e);
    runApp(_EnvErrorApp(message: e.message));
    return;
  }

  // 2. Local-first initialization — must succeed.
  await initializeDateFormatting('id_ID', null);
  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();
  await SeedService(db: db, prefs: prefs).ensureSeeded();

  // 3. Supabase — best-effort. App must boot even when offline / Supabase down.
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      // Phase 6d will inject the pinned HTTP client here.
    );
    log.i('Supabase initialized for ${Env.appEnv}');
  } catch (e, st) {
    log.w('Supabase init failed — running offline-only',
        error: e, stackTrace: st);
  }

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

    return MaterialApp.router(
      title: 'KopiyanteaPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      locale: const Locale('id', 'ID'),
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
