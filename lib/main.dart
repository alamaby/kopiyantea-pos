import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/database/seed_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'router.dart';

/// Application entry point.
///
/// Phase 2: Drift + seed.
/// Phase 6 will add: Env.validate(), Supabase.initialize(), cert pinning, secure storage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // intl date symbols for id_ID — required before any DateFormat usage.
  await initializeDateFormatting('id_ID', null);

  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();

  // Dev-only: populate dummy data on first launch.
  await SeedService(db: db, prefs: prefs).ensureSeeded();

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

  /// Reactive theme — flips between light/dark/system as the user changes
  /// the Settings preference, without restarting the app.
  ThemeMode _resolveThemeMode(WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    return switch (settings?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
