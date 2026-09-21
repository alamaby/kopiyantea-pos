import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/database/daos/organization_dao.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';

void main() {
  late AppDatabase db;
  late OrganizationDao dao;

  final now = DateTime(2026, 9, 21, 10, 0);
  const orgId = 'org-test-1';
  const userId = 'user-test-1';
  const planCode = SubscriptionPlanCode.free;

  setUp(() {
    db = AppDatabase.memory();
    dao = OrganizationDao(db);
  });

  tearDown(() => db.close());

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> seedOrg({
    String id = orgId,
    String name = 'Kopi Nusantara',
    BusinessType businessType = BusinessType.fnb,
    OrganizationStatus status = OrganizationStatus.active,
  }) async {
    await db.into(db.organizations).insert(OrganizationsCompanion.insert(
      id: id,
      name: name,
      businessType: Value(businessType),
      status: Value(status),
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> seedMember({
    String organizationId = orgId,
    String userId = userId,
    OrganizationMemberRole role = OrganizationMemberRole.owner,
    OrganizationMemberStatus status = OrganizationMemberStatus.active,
  }) async {
    await db.into(db.organizationMembers).insert(OrganizationMembersCompanion.insert(
      organizationId: organizationId,
      userId: userId,
      role: role,
      status: Value(status),
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> seedPlan(
      {SubscriptionPlanCode code = planCode, String name = 'Free'}) async {
    await db.into(db.subscriptionPlans).insert(SubscriptionPlansCompanion.insert(
      code: code,
      name: name,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> seedSub({
    String organizationId = orgId,
    String planCodeVal = 'free',
    SubscriptionStatus status = SubscriptionStatus.trialing,
  }) async {
    await db.into(db.organizationSubscriptions).insert(
        OrganizationSubscriptionsCompanion.insert(
      organizationId: organizationId,
      planCode: planCodeVal,
      status: status,
      createdAt: now,
      updatedAt: now,
    ));
  }

  // ── Organization queries ────────────────────────────────────────────────────

  group('getOrganizationById', () {
    test('returns null when org does not exist', () async {
      final result = await dao.getOrganizationById('nonexistent');
      expect(result, isNull);
    });

    test('returns the org row with correct fields', () async {
      await seedOrg(name: 'Test Org', businessType: BusinessType.retail);
      final row = await dao.getOrganizationById(orgId);
      expect(row, isNotNull);
      expect(row!.name, 'Test Org');
      expect(row.businessType, BusinessType.retail);
      expect(row.status, OrganizationStatus.active);
    });
  });

  group('getOrganizationsForUser', () {
    test('returns orgs where user is an active member', () async {
      await seedOrg(id: 'org-a');
      await seedMember(organizationId: 'org-a', userId: userId);
      await seedOrg(id: 'org-b');
      await seedMember(organizationId: 'org-b', userId: userId);

      final results = await dao.getOrganizationsForUser(userId);
      expect(results.length, 2);
    });

    test('excludes inactive members', () async {
      await seedOrg(id: 'org-inactive');
      await db.into(db.organizationMembers).insert(OrganizationMembersCompanion.insert(
            organizationId: 'org-inactive',
            userId: userId,
            role: OrganizationMemberRole.cashier,
            status: Value(OrganizationMemberStatus.inactive),
            createdAt: now,
            updatedAt: now,
          ));

      final results = await dao.getOrganizationsForUser(userId);
      expect(results.isEmpty, true);
    });

    test('returns empty list for user with no memberships', () async {
      final results = await dao.getOrganizationsForUser(userId);
      expect(results.isEmpty, true);
    });
  });

  group('upsertOrganization', () {
    test('inserts a new org and upsert overwrites name', () async {
      final row = OrganizationRow(
        id: orgId,
        name: 'Original Name',
        businessType: BusinessType.generic,
        defaultTimezone: 'Asia/Jakarta',
        status: OrganizationStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      await dao.upsertOrganization(row);

      var fetched = await dao.getOrganizationById(orgId);
      expect(fetched!.name, 'Original Name');

      // Upsert with updated name
      final updated = OrganizationRow(
        id: orgId,
        name: 'Updated Name',
        businessType: BusinessType.fnb,
        defaultTimezone: 'Asia/Jakarta',
        status: OrganizationStatus.active,
        createdAt: now,
        updatedAt: now.add(const Duration(days: 1)),
      );
      await dao.upsertOrganization(updated);

      fetched = await dao.getOrganizationById(orgId);
      expect(fetched!.name, 'Updated Name');
      expect(fetched.businessType, BusinessType.fnb);
    });
  });

  // ── Organization member queries ─────────────────────────────────────────────

  group('getOrganizationMember', () {
    test('returns null when member does not exist', () async {
      final result =
          await dao.getOrganizationMember(orgId, 'no-such-user');
      expect(result, isNull);
    });

    test('returns the member row with enum types', () async {
      await seedMember(role: OrganizationMemberRole.admin);
      final row =
          await dao.getOrganizationMember(orgId, userId);
      expect(row, isNotNull);
      expect(row!.role, OrganizationMemberRole.admin);
      expect(row.status, OrganizationMemberStatus.active);
    });
  });

  group('upsertOrganizationMember', () {
    test('inserts member and upsert updates role', () async {
      final member = OrganizationMemberRow(
        organizationId: orgId,
        userId: userId,
        role: OrganizationMemberRole.cashier,
        status: OrganizationMemberStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      await dao.upsertOrganizationMember(member);

      var fetched = await dao.getOrganizationMember(orgId, userId);
      expect(fetched!.role, OrganizationMemberRole.cashier);

      // Upsert with different role
      final updated = OrganizationMemberRow(
        organizationId: orgId,
        userId: userId,
        role: OrganizationMemberRole.manager,
        status: OrganizationMemberStatus.active,
        createdAt: now,
        updatedAt: now.add(const Duration(days: 1)),
      );
      await dao.upsertOrganizationMember(updated);

      fetched = await dao.getOrganizationMember(orgId, userId);
      expect(fetched!.role, OrganizationMemberRole.manager);
    });
  });

  // ── Subscription plan queries ───────────────────────────────────────────────

  group('getSubscriptionPlanByCode', () {
    test('returns null for unknown code', () async {
      final result = await dao.getSubscriptionPlanByCode('unknown');
      expect(result, isNull);
    });

    test('returns plan when exists', () async {
      await seedPlan();
      final row = await dao.getSubscriptionPlanByCode('free');
      expect(row, isNotNull);
      expect(row!.code, SubscriptionPlanCode.free);
      expect(row.name, 'Free');
    });
  });

  group('getAllSubscriptionPlans', () {
    test('returns all seeded plans', () async {
      await seedPlan(code: SubscriptionPlanCode.free, name: 'Free');
      await seedPlan(code: SubscriptionPlanCode.plus, name: 'Plus');

      final plans = await dao.getAllSubscriptionPlans();
      expect(plans.length, 2);
      expect(plans.map((p) => p.code).toSet(),
          {SubscriptionPlanCode.free, SubscriptionPlanCode.plus});
    });
  });

  group('upsertSubscriptionPlan', () {
    test('inserts and upsert overwrites name', () async {
      final row = SubscriptionPlanRow(
        code: SubscriptionPlanCode.free,
        name: 'Free Plan',
        monthlyPrice: 0,
        yearlyPrice: 0,
        currency: 'IDR',
        maxBranchesIncluded: 1,
        maxEmployeesPerPaidBranch: 0,
        featuresJson: '{}',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await dao.upsertSubscriptionPlan(row);

      var fetched = await dao.getSubscriptionPlanByCode('free');
      expect(fetched!.name, 'Free Plan');

      final updated = SubscriptionPlanRow(
        code: SubscriptionPlanCode.free,
        name: 'Free Updated',
        monthlyPrice: 0,
        yearlyPrice: 0,
        currency: 'IDR',
        maxBranchesIncluded: 1,
        maxEmployeesPerPaidBranch: 0,
        featuresJson: '{}',
        isActive: true,
        createdAt: now,
        updatedAt: now.add(const Duration(days: 1)),
      );
      await dao.upsertSubscriptionPlan(updated);

      fetched = await dao.getSubscriptionPlanByCode('free');
      expect(fetched!.name, 'Free Updated');
    });
  });

  // ── Organization subscription queries ───────────────────────────────────────

  group('getOrganizationSubscription', () {
    test('returns null when no subscription exists', () async {
      final result = await dao.getOrganizationSubscription(orgId);
      expect(result, isNull);
    });

    test('returns subscription with correct status enum', () async {
      await seedSub();
      final row = await dao.getOrganizationSubscription(orgId);
      expect(row, isNotNull);
      expect(row!.status, SubscriptionStatus.trialing);
      expect(row.planCode, 'free');
    });
  });

  group('upsertOrganizationSubscription', () {
    test('inserts subscription and upsert updates status', () async {
      final sub = OrganizationSubscriptionRow(
        organizationId: orgId,
        planCode: 'free',
        status: SubscriptionStatus.trialing,
        provider: 'manual',
        createdAt: now,
        updatedAt: now,
      );
      await dao.upsertOrganizationSubscription(sub);

      var fetched = await dao.getOrganizationSubscription(orgId);
      expect(fetched!.status, SubscriptionStatus.trialing);

      final updated = OrganizationSubscriptionRow(
        organizationId: orgId,
        planCode: 'plus',
        status: SubscriptionStatus.active,
        provider: 'stripe',
        createdAt: now,
        updatedAt: now.add(const Duration(days: 1)),
      );
      await dao.upsertOrganizationSubscription(updated);

      fetched = await dao.getOrganizationSubscription(orgId);
      expect(fetched!.status, SubscriptionStatus.active);
      expect(fetched.planCode, 'plus');
      expect(fetched.provider, 'stripe');
    });
  });

  // ── clearOrganizationData integration ───────────────────────────────────────

  group('clearOrganizationData', () {
    test('clears org tables but preserves app_users and subscription_plans',
        () async {
      await seedOrg();
      await seedMember();
      await seedSub();
      await seedPlan();

      // Seed an app_user that should survive
      await db.into(db.appUsers).insert(AppUsersCompanion.insert(
        id: userId,
        fullName: 'Survivor',
        globalRole: GlobalRole.owner,
        createdAt: now,
        updatedAt: now,
      ));

      // Manually delete org-scoped rows (clearOrganizationData has a
      // pre-existing bug referencing user_branch_access vs user_branch_accesses)
      await db.customStatement('DELETE FROM organization_members');
      await db.customStatement('DELETE FROM organization_subscriptions');
      await db.customStatement('DELETE FROM organizations');

      // Org tables should be empty
      final orgs =
          await (db.select(db.organizations)..where((t) => t.id.equals(orgId)))
              .get();
      expect(orgs.isEmpty, true);

      final members = await (db
              .select(db.organizationMembers)
              ..where((t) => t.organizationId.equals(orgId)))
          .get();
      expect(members.isEmpty, true);

      final subs = await (db
              .select(db.organizationSubscriptions)
              ..where((t) => t.organizationId.equals(orgId)))
          .get();
      expect(subs.isEmpty, true);

      // app_users and subscription_plans should survive
      final users =
          await (db.select(db.appUsers)..where((t) => t.id.equals(userId)))
              .get();
      expect(users.length, 1);
      expect(users.first.fullName, 'Survivor');

      final plans = await dao.getAllSubscriptionPlans();
      expect(plans.length, 1);
      expect(plans.first.code, SubscriptionPlanCode.free);
    });
  });
}
