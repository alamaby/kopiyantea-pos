import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/branch_tables.dart';

part 'branch_dao.g.dart';

@DriftAccessor(tables: [Branches, AppUsers, UserBranchAccesses])
class BranchDao extends DatabaseAccessor<AppDatabase> with _$BranchDaoMixin {
  BranchDao(super.db);

  Stream<List<BranchRow>> watchAllBranches() =>
      (select(branches)..where((b) => b.isActive.equals(true))).watch();

  Future<BranchRow?> getBranchById(String id) =>
      (select(branches)..where((b) => b.id.equals(id))).getSingleOrNull();

  Stream<BranchRow?> watchBranchById(String id) =>
      (select(branches)..where((b) => b.id.equals(id))).watchSingleOrNull();

  Future<void> upsertBranch(BranchesCompanion companion) =>
      into(branches).insertOnConflictUpdate(companion);

  Future<AppUserRow?> getUserById(String id) =>
      (select(appUsers)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<void> upsertUser(AppUsersCompanion companion) =>
      into(appUsers).insertOnConflictUpdate(companion);

  Stream<List<UserBranchAccessRow>> watchAccessForUser(String userId) =>
      (select(userBranchAccesses)
            ..where((a) => a.userId.equals(userId)))
          .watch();
}
