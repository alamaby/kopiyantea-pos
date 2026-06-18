import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/daos/dao_providers.dart';
import '../../core/sync/sync_repository.dart';
import 'auth_provider.dart';

part 'bootstrap_provider.freezed.dart';
part 'bootstrap_provider.g.dart';

const bootstrapStepBranchAccess = 'branchAccess';
const bootstrapStepMenuStock = 'menuStock';
const bootstrapStepTransactionHistory = 'transactionHistory';

const bootstrapErrorSessionMissing = 'sessionMissing';
const bootstrapErrorNoBranchAccess = 'noBranchAccess';
const bootstrapErrorMasterDataFailed = 'masterDataFailed';
const bootstrapErrorUnknownPrefix = 'unknown:';

/// Post-login data hydration state.
///
/// `complete` is the default — set when the cache is trusted (session
/// restore from previous launch). `pending` is set the moment an explicit
/// sign-in succeeds; the [BootstrapScreen] then runs the pull pipeline,
/// emitting `running(step)` updates so the UI can show progress. On any
/// failure → `failed(error)` with retry affordance.
@freezed
sealed class BootstrapState with _$BootstrapState {
  const factory BootstrapState.complete() = BootstrapComplete;
  const factory BootstrapState.pending() = BootstrapPending;
  const factory BootstrapState.running({required String step}) =
      BootstrapRunning;
  const factory BootstrapState.failed({required String error}) =
      BootstrapFailed;
}

@Riverpod(keepAlive: true)
class Bootstrap extends _$Bootstrap {
  @override
  BootstrapState build() => const BootstrapState.complete();

  /// Mark fresh-login state — UI will navigate to /bootstrap and call [run].
  void markPending() => state = const BootstrapState.pending();

  /// Reset to complete — used when the user signs out, so a future sign-in
  /// starts from a clean slate.
  void reset() => state = const BootstrapState.complete();

  /// Sequentially pulls master + transaction history. Each step transitions
  /// the state with a human-readable label for the UI.
  Future<void> run() async {
    final repo = ref.read(syncRepositoryProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const BootstrapState.failed(
        error: bootstrapErrorSessionMissing,
      );
      return;
    }

    try {
      state = const BootstrapState.running(step: bootstrapStepBranchAccess);
      // pullMyAuthContext was already called inside signIn — re-running is
      // idempotent and ensures the local user/access cache is fresh.
      await repo.pullMyAuthContext(user.id);

      final orgId = ref.read(currentOrganizationIdProvider);
      if (orgId == null) {
        state = const BootstrapState.failed(
          error: bootstrapErrorNoBranchAccess,
        );
        return;
      }

      final branchIds = await _accessibleBranchIds(user.id, orgId);
      if (branchIds.isEmpty) {
        state = const BootstrapState.failed(
          error: bootstrapErrorNoBranchAccess,
        );
        return;
      }

      state = const BootstrapState.running(step: bootstrapStepMenuStock);
      final master = await repo.pullMasterData(
        branchIds: branchIds,
        organizationId: orgId,
      );
      if (master.errors > 0 && master.upserted == 0) {
        state = const BootstrapState.failed(
          error: bootstrapErrorMasterDataFailed,
        );
        return;
      }

      state =
          const BootstrapState.running(step: bootstrapStepTransactionHistory);
      await repo.pullTransactions(
        branchIds: branchIds,
        organizationId: orgId,
      );

      state = const BootstrapState.complete();
    } catch (e) {
      state = BootstrapState.failed(
        error: '$bootstrapErrorUnknownPrefix$e',
      );
    }
  }

  Future<List<String>> _accessibleBranchIds(
    String userId,
    String orgId,
  ) async {
    final dao = ref.read(branchDaoProvider);
    final rows = await dao.getAccessForUserInOrg(userId, orgId);
    return rows.map((r) => r.branchId).toList();
  }
}
