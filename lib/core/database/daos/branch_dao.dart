import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/branch_tables.dart';

part 'branch_dao.g.dart';

@DriftAccessor(tables: [
  Branches,
  AppUsers,
  UserBranchAccesses,
  PendingInvitations,
])
class BranchDao extends DatabaseAccessor<AppDatabase> with _$BranchDaoMixin {
  BranchDao(super.db);

  // ── Branches ────────────────────────────────────────────────────────────────

  Stream<List<BranchRow>> watchAllBranches() =>
      (select(branches)..where((b) => b.isActive.equals(true))).watch();

  /// Snapshot read — used by use cases that need to propagate to all branches
  /// (e.g. creating a master product auto-adds it to every active branch).
  Future<List<BranchRow>> getActiveBranches() =>
      (select(branches)..where((b) => b.isActive.equals(true))).get();

  Future<BranchRow?> getBranchById(String id) =>
      (select(branches)..where((b) => b.id.equals(id))).getSingleOrNull();

  Stream<BranchRow?> watchBranchById(String id) =>
      (select(branches)..where((b) => b.id.equals(id))).watchSingleOrNull();

  Future<void> upsertBranch(BranchesCompanion companion) =>
      into(branches).insertOnConflictUpdate(companion);

  /// Partial update — only touches the columns provided. Used by Tax Settings
  /// UI so unrelated fields (address/phone) aren't clobbered.
  Future<int> updateById(String id, BranchesCompanion patch) =>
      (update(branches)..where((b) => b.id.equals(id))).write(patch);

  // ── App users ───────────────────────────────────────────────────────────────

  Stream<List<AppUserRow>> watchAllUsers() => (select(appUsers)
        ..orderBy([(u) => OrderingTerm.asc(u.fullName)]))
      .watch();

  Future<AppUserRow?> getUserById(String id) =>
      (select(appUsers)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<AppUserRow?> getUserByEmail(String email) => (select(appUsers)
        ..where((u) => u.email.equals(email)))
      .getSingleOrNull();

  Future<void> upsertUser(AppUsersCompanion companion) =>
      into(appUsers).insertOnConflictUpdate(companion);

  Future<int> updateUserById(String id, AppUsersCompanion patch) =>
      (update(appUsers)..where((u) => u.id.equals(id))).write(patch);

  Future<int> setUserActive(String id, {required bool isActive}) =>
      (update(appUsers)..where((u) => u.id.equals(id))).write(
        AppUsersCompanion(
          isActive: Value(isActive),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ── User-branch access ──────────────────────────────────────────────────────

  Future<void> upsertUserBranchAccess(UserBranchAccessesCompanion companion) =>
      into(userBranchAccesses).insertOnConflictUpdate(companion);

  Stream<List<UserBranchAccessRow>> watchAccessForUser(String userId) =>
      (select(userBranchAccesses)
            ..where((a) => a.userId.equals(userId)))
          .watch();

  Future<List<UserBranchAccessRow>> getAccessForUser(String userId) =>
      (select(userBranchAccesses)..where((a) => a.userId.equals(userId)))
          .get();

  /// FEAT-002 Phase 7 — returns branch IDs the user can access in the given org.
  /// Local Branches has no organization_id (single-tenant Drift schema).
  /// Scope check: user must be active member of orgId, then return all
  /// branchIds the user can access. Preserves single-tenant behavior.
  Future<List<String>> getBranchIdsForUserInOrg(
    String userId,
    String orgId,
  ) async {
    if (userId.isEmpty || orgId.isEmpty) return <String>[];
    final member = await customSelect(
      'SELECT 1 AS ok FROM organization_members '
      'WHERE organization_id = ? AND user_id = ? AND status = ?',
      variables: [
        Variable<String>(orgId),
        Variable<String>(userId),
        Variable<String>('active'),
      ],
    ).getSingleOrNull();
    if (member == null) return <String>[];
    final rows = await customSelect(
      'SELECT branch_id FROM user_branch_accesses WHERE user_id = ?',
      variables: [Variable<String>(userId)],
    ).get();

    return rows.map((row) => row.read<String>('branch_id')).toList();
  }

  Future<int> deleteAccess({
    required String userId,
    required String branchId,
  }) =>
      (delete(userBranchAccesses)
            ..where((a) =>
                a.userId.equals(userId) & a.branchId.equals(branchId)))
          .go();

  Future<int> deleteAllAccessForUser(String userId) =>
      (delete(userBranchAccesses)..where((a) => a.userId.equals(userId))).go();

  // ── Pending invitations ─────────────────────────────────────────────────────

  Stream<List<PendingInvitationRow>> watchPendingInvitations() =>
      (select(pendingInvitations)
            ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
          .watch();

  Future<PendingInvitationRow?> getPendingInvitationByEmail(String email) =>
      (select(pendingInvitations)..where((i) => i.email.equals(email)))
          .getSingleOrNull();

  Future<void> upsertPendingInvitation(
    PendingInvitationsCompanion companion,
  ) =>
      into(pendingInvitations).insertOnConflictUpdate(companion);

  Future<int> deletePendingInvitation(String id) =>
      (delete(pendingInvitations)..where((i) => i.id.equals(id))).go();
}
