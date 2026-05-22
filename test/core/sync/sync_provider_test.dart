import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/database/database_provider.dart';
import 'package:kopiyantea_pos/core/sync/sync_provider.dart';
import 'package:kopiyantea_pos/core/sync/sync_repository.dart';
import 'package:kopiyantea_pos/features/auth/auth_provider.dart';

import '../../helpers/test_db.dart';

/// Validates TODO-BG-SYNC-ON-RESUME behaviour on the [Sync] notifier:
/// - dedupe in-flight
/// - throttle within minInterval
/// - no-op when unauthenticated
/// - fire when stale or forced
class _FakeSyncRepo extends SyncRepository {
  _FakeSyncRepo(super.ref);

  int pushCalls = 0;
  int masterCalls = 0;
  int txCalls = 0;
  Completer<void>? pushGate;

  @override
  Future<PushSummary> pushOutbox() async {
    pushCalls++;
    if (pushGate != null) await pushGate!.future;
    return const PushSummary(pushed: 0, failed: 0);
  }

  @override
  Future<({int errors, int upserted})> pullMasterData(
      List<String> branchIds) async {
    masterCalls++;
    return (upserted: 3, errors: 0);
  }

  @override
  Future<({int errors, int upserted})> pullTransactions(
    List<String> branchIds, {
    int limit = 100,
  }) async {
    txCalls++;
    return (upserted: 2, errors: 0);
  }
}

void main() {
  late AppDatabase db;
  late _FakeSyncRepo fake;

  setUp(() async {
    db = AppDatabase.memory();
    await seedMinimal(db);
  });

  tearDown(() => db.close());

  Future<AppUserRow> _seededUser() => (db.select(db.appUsers)
        ..where((u) => u.id.equals(TestIds.user)))
      .getSingle();

  ProviderContainer _container({AppUserRow? user}) {
    final overrides = <Override>[
      databaseProvider.overrideWithValue(db),
      syncRepositoryProvider.overrideWith((ref) {
        fake = _FakeSyncRepo(ref);
        return fake;
      }),
      currentUserProvider.overrideWith((ref) => user),
    ];
    final c = ProviderContainer(overrides: overrides);
    // Eagerly materialize syncRepositoryProvider so [fake] is assigned before
    // any test reads `fake.pushCalls`. Without this, the override factory
    // only runs the first time the provider is read inside bgSyncIfStale.
    c.read(syncRepositoryProvider);
    return c;
  }

  test('no-op when no user is authenticated', () async {
    final c = _container(user: null);
    addTearDown(c.dispose);

    await c.read(syncProvider.notifier).bgSyncIfStale();

    expect(c.read(syncProvider).lastSyncAt, isNull);
    expect(fake.pushCalls, 0);
    expect(fake.masterCalls, 0);
    expect(fake.txCalls, 0);
  });

  test('forces a pull when minInterval = Duration.zero', () async {
    final user = await _seededUser();
    final c = _container(user: user);
    addTearDown(c.dispose);

    await c
        .read(syncProvider.notifier)
        .bgSyncIfStale(minInterval: Duration.zero);

    final state = c.read(syncProvider);
    expect(state.lastSyncAt, isNotNull);
    expect(fake.pushCalls, 1);
    expect(fake.masterCalls, 1);
    expect(fake.txCalls, 1);
    // master(3) + tx(2) = 5
    expect(state.lastPulled, 5);
  });

  test('throttles a second call within minInterval', () async {
    final user = await _seededUser();
    final c = _container(user: user);
    addTearDown(c.dispose);

    final notifier = c.read(syncProvider.notifier);
    await notifier.bgSyncIfStale(minInterval: Duration.zero);
    expect(fake.pushCalls, 1);

    // Second call with 5-minute throttle should NOT re-fire — lastSyncAt is
    // basically "now" after the first call.
    await notifier.bgSyncIfStale(minInterval: const Duration(minutes: 5));
    expect(fake.pushCalls, 1, reason: 'throttle should suppress re-fire');
    expect(fake.masterCalls, 1);
    expect(fake.txCalls, 1);
  });

  test('dedupes when a sync is already in flight', () async {
    final user = await _seededUser();
    final c = _container(user: user);
    addTearDown(c.dispose);

    final notifier = c.read(syncProvider.notifier);
    fake.pushGate = Completer<void>();

    // Kick off first sync but don't await — it parks at pushOutbox.
    final first = notifier.bgSyncIfStale(minInterval: Duration.zero);
    // Allow the microtask to advance into pushOutbox.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(c.read(syncProvider).isSyncing, isTrue);

    // Second call must short-circuit on `state.isSyncing`.
    await notifier.bgSyncIfStale(minInterval: Duration.zero);
    expect(fake.pushCalls, 1, reason: 'second call should be deduped');

    // Release the gate and let the first sync finish.
    fake.pushGate!.complete();
    await first;
    expect(c.read(syncProvider).isSyncing, isFalse);
  });

  test('fires again once minInterval has elapsed', () async {
    final user = await _seededUser();
    final c = _container(user: user);
    addTearDown(c.dispose);

    final notifier = c.read(syncProvider.notifier);
    await notifier.bgSyncIfStale(minInterval: Duration.zero);
    expect(fake.pushCalls, 1);

    // A zero-interval call always fires regardless of recency.
    await notifier.bgSyncIfStale(minInterval: Duration.zero);
    expect(fake.pushCalls, 2);
  });
}
