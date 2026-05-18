import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/daos/dao_providers.dart';
import 'sync_repository.dart';

part 'sync_provider.freezed.dart';
part 'sync_provider.g.dart';

/// UI-visible sync state: spinner gate, last success timestamp, last error.
@freezed
class SyncState with _$SyncState {
  const factory SyncState({
    @Default(false) bool isSyncing,
    DateTime? lastSyncAt,
    String? lastError,
    @Default(0) int lastPushed,
    @Default(0) int lastFailed,
  }) = _SyncState;
}

@riverpod
class Sync extends _$Sync {
  @override
  SyncState build() => const SyncState();

  /// Manual sync trigger — push outbox + (Phase 6e2) pull master. Returns
  /// the new state for the caller to inspect.
  Future<SyncState> syncNow() async {
    if (state.isSyncing) return state;
    state = state.copyWith(isSyncing: true, lastError: null);
    try {
      final repo = ref.read(syncRepositoryProvider);
      final result = await repo.pushOutbox();
      state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        lastPushed: result.pushed,
        lastFailed: result.failed,
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
