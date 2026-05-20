import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/daos/dao_providers.dart';
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
}

/// Reactive count of outbox rows waiting to push.
@riverpod
Stream<int> pendingOutboxCount(PendingOutboxCountRef ref) =>
    ref.watch(outboxDaoProvider).watchPendingCount();
