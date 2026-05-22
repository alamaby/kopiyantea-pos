import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/daos/dao_providers.dart';
import '../../features/auth/auth_provider.dart';
import 'sync_repository.dart';

part 'sync_provider.freezed.dart';
part 'sync_provider.g.dart';

/// UI-visible sync state: spinner gate, last success timestamp, counters.
@freezed
class SyncState with _$SyncState {
  const factory SyncState({
    @Default(false) bool isSyncing,
    DateTime? lastSyncAt,
    String? lastError,
    @Default(0) int lastPushed,
    @Default(0) int lastFailed,
    @Default(0) int lastPulled,
  }) = _SyncState;
}

/// keepAlive: true — sync state (last timestamp, counters) must survive
/// navigation away from Settings; otherwise the user always sees
/// "Belum pernah" because the provider rebuilds fresh on every visit.
@Riverpod(keepAlive: true)
class Sync extends _$Sync {
  final Logger _log = Logger();

  @override
  SyncState build() => const SyncState();

  /// Manual sync: push outbox + pull master data + pull recent transactions
  /// for the active branch.
  Future<SyncState> syncNow({List<String>? branchIds}) async {
    if (state.isSyncing) return state;
    state = state.copyWith(isSyncing: true, lastError: null);
    try {
      final repo = ref.read(syncRepositoryProvider);
      final push = await repo.pushOutbox();
      final hasBranches = branchIds != null && branchIds.isNotEmpty;
      final master = hasBranches
          ? await repo.pullMasterData(branchIds)
          : (upserted: 0, errors: 0);
      final txn = hasBranches
          ? await repo.pullTransactions(branchIds)
          : (upserted: 0, errors: 0);
      state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        lastPushed: push.pushed,
        lastFailed: push.failed,
        lastPulled: master.upserted + txn.upserted,
      );
    } catch (e) {
      state = state.copyWith(isSyncing: false, lastError: e.toString());
    }
    return state;
  }

  /// Background re-sync (TODO-BG-SYNC-ON-RESUME). Resolves accessible branches
  /// for the current user and runs [syncNow] when the cache looks stale.
  ///
  /// - Dedupes against an in-flight sync (returns immediately).
  /// - Skips when `lastSyncAt` is within [minInterval]. Pass [Duration.zero]
  ///   to force a sync regardless of recency (used on session restore).
  /// - Silent: errors are swallowed and surfaced via [SyncState.lastError]
  ///   — callers fire-and-forget.
  Future<void> bgSyncIfStale({
    Duration minInterval = const Duration(minutes: 5),
  }) async {
    if (state.isSyncing) return;
    final last = state.lastSyncAt;
    if (last != null &&
        minInterval > Duration.zero &&
        DateTime.now().difference(last) < minInterval) {
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final dao = ref.read(branchDaoProvider);
      final access = await dao.getAccessForUser(user.id);
      final branchIds = access.map((a) => a.branchId).toList();
      if (branchIds.isEmpty) return;
      _log.i('[Sync] bg sync triggered (branches=${branchIds.length})');
      await syncNow(branchIds: branchIds);
    } catch (e) {
      _log.w('[Sync] bg sync failed: $e');
    }
  }
}

/// Reactive count of outbox rows waiting to push.
@riverpod
Stream<int> pendingOutboxCount(PendingOutboxCountRef ref) =>
    ref.watch(outboxDaoProvider).watchPendingCount();
