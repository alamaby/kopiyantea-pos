import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/secure_storage.dart';

/// SupabaseClient is initialized once in main.dart via `Supabase.initialize`.
/// This provider just exposes the singleton — feature code never calls
/// `Supabase.instance.client` directly.
final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

/// Single SecureStorage instance — Keychain on iOS, encrypted SharedPreferences
/// on Android. Used for auth tokens only.
final secureStorageProvider = Provider<SecureStorage>(
  (_) => SecureStorage(),
);
