import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';

part 'user_providers.g.dart';

/// FEAT-006 — reactive list of all `app_users` (active + inactive).
@riverpod
Stream<List<AppUserRow>> allUsers(AllUsersRef ref) {
  return ref.watch(branchDaoProvider).watchAllUsers();
}

/// Reactive list of pending invitations.
@riverpod
Stream<List<PendingInvitationRow>> pendingInvitations(
  PendingInvitationsRef ref,
) {
  return ref.watch(branchDaoProvider).watchPendingInvitations();
}

/// Branch access rows for a single user — reactive so toggling cabang
/// updates the form live.
@riverpod
Stream<List<UserBranchAccessRow>> userAccess(
  UserAccessRef ref,
  String userId,
) {
  return ref.watch(branchDaoProvider).watchAccessForUser(userId);
}
