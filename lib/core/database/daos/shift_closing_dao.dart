import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/shift_closing_table.dart';

part 'shift_closing_dao.g.dart';

@DriftAccessor(tables: [ShiftClosings])
class ShiftClosingDao extends DatabaseAccessor<AppDatabase>
    with _$ShiftClosingDaoMixin {
  ShiftClosingDao(super.db);

  Stream<List<ShiftClosingRow>> watchForBranch(String branchId,
          {int limit = 30}) =>
      (select(shiftClosings)
            ..where((s) => s.branchId.equals(branchId))
            ..orderBy([(s) => OrderingTerm.desc(s.closedAt)])
            ..limit(limit))
          .watch();

  Future<void> insert(ShiftClosingsCompanion companion) =>
      into(shiftClosings).insert(companion);

  Future<ShiftClosingRow?> getLatestForBranch(String branchId) =>
      (select(shiftClosings)
            ..where((s) => s.branchId.equals(branchId))
            ..orderBy([(s) => OrderingTerm.desc(s.closedAt)])
            ..limit(1))
          .getSingleOrNull();
}
