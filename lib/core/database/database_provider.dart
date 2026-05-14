import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Override this with the real [AppDatabase] instance at app startup
/// (see `main.dart`). Any provider that reads the database depends on this.
final databaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError(
    'databaseProvider must be overridden in main.dart via ProviderScope.overrides',
  ),
);
