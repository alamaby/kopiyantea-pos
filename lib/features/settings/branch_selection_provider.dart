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
/// Returns null when no branch is selected (first run before seed).
@riverpod
Future<BranchRow?> selectedBranch(SelectedBranchRef ref) async {
  final settings = await ref.watch(settingsNotifierProvider.future);
  final id = settings.selectedBranchId;
  if (id == null) return null;
  return ref.watch(branchDaoProvider).getBranchById(id);
}
