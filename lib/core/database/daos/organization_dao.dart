import 'package:drift/drift.dart';

import '../app_database.dart';

/// DAO for SaaS multi-tenant tables.
///
/// TD-001 resolved 2026-09-21 — uses typed Drift queries with generated
/// Row types ([OrganizationRow], [OrganizationMemberRow], etc.) instead of
/// raw SQL / customSelect.
class OrganizationDao {
  OrganizationDao(this._db);

  final AppDatabase _db;

  // ── Organization queries ───────────────────────────────────────────────────

  Future<OrganizationRow?> getOrganizationById(String id) =>
      (_db.select(_db.organizations)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<OrganizationRow>> getOrganizationsForUser(String userId) {
    final q = _db.select(_db.organizations).join([
      innerJoin(
        _db.organizationMembers,
        _db.organizationMembers.organizationId.equalsExp(
          _db.organizations.id,
        ),
      ),
    ])
      ..where(
        _db.organizationMembers.userId.equals(userId) &
            _db.organizationMembers.status.equals('active'),
      );
    return q.map((row) => row.readTable(_db.organizations)).get();
  }

  Future<OrganizationRow?> getOrganizationForUser(String userId) async {
    final orgs = await getOrganizationsForUser(userId);
    return orgs.isNotEmpty ? orgs.first : null;
  }

  Future<void> upsertOrganization(OrganizationRow row) => _db
      .into(_db.organizations)
      .insertOnConflictUpdate(row.toCompanion(false));

  // ── Organization member queries ────────────────────────────────────────────

  Future<OrganizationMemberRow?> getOrganizationMember(
    String organizationId,
    String userId,
  ) =>
      (_db.select(_db.organizationMembers)
        ..where(
          (t) =>
              t.organizationId.equals(organizationId) & t.userId.equals(userId),
        ))
          .getSingleOrNull();

  Future<void> upsertOrganizationMember(OrganizationMemberRow row) => _db
      .into(_db.organizationMembers)
      .insertOnConflictUpdate(row.toCompanion(false));

  // ── Subscription plan queries ──────────────────────────────────────────────

  Future<SubscriptionPlanRow?> getSubscriptionPlanByCode(String code) =>
      (_db.select(_db.subscriptionPlans)
        ..where((t) => t.code.equals(code)))
          .getSingleOrNull();

  Future<List<SubscriptionPlanRow>> getAllSubscriptionPlans() =>
      _db.select(_db.subscriptionPlans).get();

  Future<void> upsertSubscriptionPlan(SubscriptionPlanRow row) => _db
      .into(_db.subscriptionPlans)
      .insertOnConflictUpdate(row.toCompanion(false));

  // ── Organization subscription queries ──────────────────────────────────────

  Future<OrganizationSubscriptionRow?> getOrganizationSubscription(
    String organizationId,
  ) =>
      (_db.select(_db.organizationSubscriptions)
        ..where((t) => t.organizationId.equals(organizationId)))
          .getSingleOrNull();

  Future<void> upsertOrganizationSubscription(
    OrganizationSubscriptionRow row,
  ) =>
      _db
          .into(_db.organizationSubscriptions)
          .insertOnConflictUpdate(row.toCompanion(false));
}
