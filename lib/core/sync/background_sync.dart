import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/env.dart';
import '../database/app_database.dart';
import '../database/daos/dao_providers.dart';
import '../database/database_provider.dart';
import '../logging/app_logger.dart';
import '../network/pinned_http_client.dart';
import 'sync_repository.dart';

const kBackgroundSyncTask = 'kopiyantea.backgroundSync';
const kBackgroundSyncUniqueName = 'kopiyantea.backgroundSync.periodic';

/// WorkManager callback entrypoint.
///
/// Android runs this in a background Flutter isolate. Keep dependencies minimal:
/// initialize platform bindings, open the local database, restore Supabase
/// session, then reuse [SyncRepository] so foreground and background sync share
/// the same push/pull behavior.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kBackgroundSyncTask && task != Workmanager.iOSBackgroundTask) {
      return true;
    }
    return runBackgroundSyncOnce();
  });
}

/// Registers the periodic OS-level background sync.
///
/// WorkManager is best-effort: Android generally honors the 15 minute minimum
/// window when constraints allow it, while iOS decides opportunistically.
Future<void> initializeBackgroundSync() async {
  final log = AppLogger.instance;
  try {
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      kBackgroundSyncUniqueName,
      kBackgroundSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
    log.i('Background sync registered');
  } catch (e, st) {
    log.w('Background sync registration skipped', error: e, stackTrace: st);
  }
}

@visibleForTesting
Future<bool> runBackgroundSyncOnce() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  final log = AppLogger.instance;

  try {
    Env.validate();
  } catch (e) {
    log.w('Background sync skipped: invalid env', error: e);
    return false;
  }

  final db = await AppDatabase.open();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );

  try {
    await _ensureSupabaseInitialized();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      log.i('Background sync skipped: no restored Supabase session');
      return true;
    }

    final repo = container.read(syncRepositoryProvider);
    final branchDao = container.read(branchDaoProvider);
    var access = await branchDao.getAccessForUser(userId);

    if (access.isEmpty) {
      final pulledAuth = await repo.pullMyAuthContext(userId);
      if (pulledAuth) {
        access = await branchDao.getAccessForUser(userId);
      }
    }

    final branchIds = access.map((a) => a.branchId).toList(growable: false);
    final push = await repo.pushOutbox();
    var pulled = 0;
    var pullErrors = 0;

    if (branchIds.isNotEmpty) {
      final master = await repo.pullMasterData(branchIds);
      final tx = await repo.pullTransactions(branchIds, limit: 50);
      pulled = master.upserted + tx.upserted;
      pullErrors = master.errors + tx.errors;
    }

    log.i(
      'Background sync finished: pushed=${push.pushed}, '
      'failed=${push.failed}, pulled=$pulled, pullErrors=$pullErrors',
    );
    return true;
  } catch (e, st) {
    log.w('Background sync failed', error: e, stackTrace: st);
    return false;
  } finally {
    container.dispose();
    await db.close();
  }
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabasePublishableKey,
      httpClient: buildPinnedHttpClient(Env.certFingerprints),
    );
  }
}
