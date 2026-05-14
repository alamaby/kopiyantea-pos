import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'router.dart';

/// Application entry point.
///
/// Phase 2: Drift database opened and injected via [databaseProvider] override.
/// Phase 6 will add: Env.validate(), Supabase.initialize(), cert pinning, secure storage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 6 will enable:
  //   Env.validate();
  //   await SecureStorage.init();
  //   await Supabase.initialize(url: Env.supabaseUrl, ...);

  final db = await AppDatabase.open();

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
    return MaterialApp.router(
      title: 'KopiyanteaPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      locale: const Locale('id', 'ID'),
    );
  }
}
