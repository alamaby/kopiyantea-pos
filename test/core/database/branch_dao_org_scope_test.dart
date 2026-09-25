import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/database/daos/branch_dao.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';

void main() {
  late AppDatabase db;
  late BranchDao dao;
  final now = DateTime(2026, 9, 25, 10, 0);

  setUp(() async {
    db = AppDatabase.memory();
    dao = BranchDao(db);
    await db.into(db.organizations).insert(OrganizationsCompanion.insert(
          id: 'org-1',
          name: 'Org Satu',
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.branches).insert(BranchesCompanion.insert(
          id: 'b1',
          name: 'Cabang 1',
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.branches).insert(BranchesCompanion.insert(
          id: 'b2',
          name: 'Cabang 2',
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.appUsers).insert(AppUsersCompanion.insert(
          id: 'u1',
          fullName: 'User Satu',
          globalRole: GlobalRole.cashier,
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.organizationMembers).insert(
          OrganizationMembersCompanion.insert(
            organizationId: 'org-1',
            userId: 'u1',
            role: OrganizationMemberRole.cashier,
            status: const Value(OrganizationMemberStatus.active),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.userBranchAccesses).insert(
          UserBranchAccessesCompanion.insert(
            userId: 'u1',
            branchId: 'b1',
            roleAtBranch: const Value(BranchRole.cashier),
          ),
        );
  });

  tearDown(() => db.close());

  test('returns accessible branches for active member', () async {
    expect(await dao.getBranchIdsForUserInOrg('u1', 'org-1'), ['b1']);
  });

  test('returns empty for unknown org', () async {
    expect(await dao.getBranchIdsForUserInOrg('u1', 'org-other'), isEmpty);
  });

  test('returns empty for user without membership', () async {
    expect(await dao.getBranchIdsForUserInOrg('u-noaccess', 'org-1'), isEmpty);
  });
}
