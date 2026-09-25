import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 25, 10, 0);

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() => db.close());

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  Future<void> seedOrgExtras() async {
    await db.into(db.organizations).insert(OrganizationsCompanion.insert(
          id: 'org-1',
          name: 'Org Tes',
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.organizationMembers).insert(
          OrganizationMembersCompanion.insert(
            organizationId: 'org-1',
            userId: TestIds.user,
            role: OrganizationMemberRole.owner,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.subscriptionPlans).insert(
          SubscriptionPlansCompanion.insert(
            code: SubscriptionPlanCode.free,
            name: 'Free',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.organizationSubscriptions).insert(
          OrganizationSubscriptionsCompanion.insert(
            organizationId: 'org-1',
            planCode: 'free',
            status: SubscriptionStatus.trialing,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.outboxItems).insert(OutboxItemsCompanion.insert(
          id: 'outbox-keep',
          entityType: OutboxEntityType.transaction,
          payload: '{"id":"outbox-keep"}',
          createdAt: now,
        ));
    await db.customStatement(
      'INSERT OR IGNORE INTO company_settings '
      '(id, receipt_logo_url, show_receipt_logo, receipt_logo_position, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        'global',
        null,
        0,
        'top',
        now.toIso8601String(),
      ],
    );
  }

  test('clearOrganizationData clears org data but retains globals', () async {
    await seedMinimal(db);
    await seedOrgExtras();

    await db.clearOrganizationData();

    expect(await count('user_branch_accesses'), 0);
    expect(await count('branches'), 0);
    expect(await count('products'), 0);
    expect(await count('organizations'), 0);
    expect(await count('app_users'), 1);
    expect(await count('subscription_plans'), 1);
    expect(await count('outbox_items'), 1);
    expect(await count('company_settings'), 1);
  });

  test('clearOrganizationData is idempotent on empty db', () async {
    await db.clearOrganizationData();
    await db.clearOrganizationData();

    expect(await count('branches'), 0);
    expect(await count('organizations'), 0);
  });

  test('clearOrganizationData survives legacy db missing usage_counters',
      () async {
    await seedMinimal(db);
    await db.customStatement('DROP TABLE IF EXISTS usage_counters');

    await db.clearOrganizationData();

    expect(await count('user_branch_accesses'), 0);
    expect(await count('branches'), 0);
    expect(await count('usage_counters'), 0);
  });
}
