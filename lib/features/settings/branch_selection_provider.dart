import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import 'settings_provider.dart';

part 'branch_selection_provider.g.dart';

/// All branches the device has access to (reactive — updates when the
/// branches table changes).
@riverpod
Stream<List<BranchRow>> allBranches(AllBranchesRef ref) {
  return ref.watch(branchDaoProvider).watchAllBranches();
}

/// The currently active branch, derived from [SettingsNotifier.selectedBranchId].
/// Returns null when no branch is selected (first run before bootstrap pull).
///
/// Reactive (Stream) so changes to the branch row (e.g. tax % update via
/// Tax Settings) flow into screens watching this provider — otherwise the
/// POS cart would keep a stale `BranchRow` snapshot.
@riverpod
Stream<BranchRow?> selectedBranch(SelectedBranchRef ref) async* {
  final settings = await ref.watch(settingsNotifierProvider.future);
  final id = settings.selectedBranchId;
  if (id == null) {
    yield null;
    return;
  }
  yield* ref.watch(branchDaoProvider).watchBranchById(id);
}
