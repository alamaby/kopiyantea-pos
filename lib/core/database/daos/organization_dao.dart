import 'package:drift/drift.dart';

import '../app_database.dart';

/// DAO for SaaS multi-tenant tables.
///
/// Note: Drift codegen is blocked by analyzer version mismatch (TD-001).
/// This DAO uses raw SQL / customSelect instead of generated helpers.
class OrganizationDao {
  OrganizationDao(this._db);

  final AppDatabase _db;

  // ── Organization queries ───────────────────────────────────────────────────

  Future<OrganizationRow?> getOrganizationById(String id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM organizations WHERE id = ?',
      variables: [Variable<String>(id)],
    ).getSingleOrNull();
    return rows == null ? null : _mapOrganizationRow(rows);
  }

  Future<List<OrganizationRow>> getOrganizationsForUser(String userId) async {
    final rows = await _db.customSelect(
      'SELECT o.* FROM organizations o '
      'JOIN organization_members om ON om.organization_id = o.id '
      'WHERE om.user_id = ? AND om.status = ?',
      variables: [Variable<String>(userId), const Variable<String>('active')],
    ).get();
    return rows.map(_mapOrganizationRow).toList();
  }

  Future<OrganizationRow?> getOrganizationForUser(String userId) async {
    final orgs = await getOrganizationsForUser(userId);
    return orgs.isNotEmpty ? orgs.first : null;
  }

  Future<void> upsertOrganization(OrganizationRow row) async {
    await _db.customStatement(
      'INSERT INTO organizations '
      '(id, name, business_type, address, phone, owner_user_id, default_timezone, '
      'status, trial_ends_at, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET '
      'name = excluded.name, business_type = excluded.business_type, '
      'address = excluded.address, phone = excluded.phone, '
      'owner_user_id = excluded.owner_user_id, default_timezone = excluded.default_timezone, '
      'status = excluded.status, trial_ends_at = excluded.trial_ends_at, '
      'updated_at = excluded.updated_at',
      [
        row.id, row.name, row.businessType, row.address, row.phone,
        row.ownerUserId, row.defaultTimezone, row.status,
        row.trialEndsAt?.toIso8601String(),
        row.createdAt.toIso8601String(), row.updatedAt.toIso8601String(),
      ],
    );
  }

  // ── Organization member queries ────────────────────────────────────────────

  Future<OrganizationMemberRow?> getOrganizationMember(
    String organizationId,
    String userId,
  ) async {
    final rows = await _db.customSelect(
      'SELECT * FROM organization_members '
      'WHERE organization_id = ? AND user_id = ?',
      variables: [
        Variable<String>(organizationId),
        Variable<String>(userId),
      ],
    ).getSingleOrNull();
    return rows == null ? null : _mapOrganizationMemberRow(rows);
  }

  Future<void> upsertOrganizationMember(OrganizationMemberRow row) async {
    await _db.customStatement(
      'INSERT INTO organization_members '
      '(organization_id, user_id, role, status, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(organization_id, user_id) DO UPDATE SET '
      'role = excluded.role, status = excluded.status, '
      'updated_at = excluded.updated_at',
      [
        row.organizationId, row.userId, row.role, row.status,
        row.createdAt.toIso8601String(), row.updatedAt.toIso8601String(),
      ],
    );
  }

  // ── Subscription plan queries ──────────────────────────────────────────────

  Future<SubscriptionPlanRow?> getSubscriptionPlanByCode(String code) async {
    final rows = await _db.customSelect(
      'SELECT * FROM subscription_plans WHERE code = ?',
      variables: [Variable<String>(code)],
    ).getSingleOrNull();
    return rows == null ? null : _mapSubscriptionPlanRow(rows);
  }

  Future<List<SubscriptionPlanRow>> getAllSubscriptionPlans() async {
    final rows = await _db.customSelect('SELECT * FROM subscription_plans').get();
    return rows.map(_mapSubscriptionPlanRow).toList();
  }

  Future<void> upsertSubscriptionPlan(SubscriptionPlanRow row) async {
    await _db.customStatement(
      'INSERT INTO subscription_plans '
      '(code, name, monthly_price, yearly_price, currency, max_products, '
      'max_monthly_transactions, max_branches_included, max_employees_per_paid_branch, '
      'features_json, is_active, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(code) DO UPDATE SET '
      'name = excluded.name, monthly_price = excluded.monthly_price, '
      'yearly_price = excluded.yearly_price, currency = excluded.currency, '
      'max_products = excluded.max_products, max_monthly_transactions = excluded.max_monthly_transactions, '
      'max_branches_included = excluded.max_branches_included, '
      'max_employees_per_paid_branch = excluded.max_employees_per_paid_branch, '
      'features_json = excluded.features_json, is_active = excluded.is_active, '
      'updated_at = excluded.updated_at',
      [
        row.code, row.name, row.monthlyPrice, row.yearlyPrice, row.currency,
        row.maxProducts, row.maxMonthlyTransactions, row.maxBranchesIncluded,
        row.maxEmployeesPerPaidBranch, row.featuresJson, row.isActive ? 1 : 0,
        row.createdAt.toIso8601String(), row.updatedAt.toIso8601String(),
      ],
    );
  }

  // ── Organization subscription queries ──────────────────────────────────────

  Future<OrganizationSubscriptionRow?> getOrganizationSubscription(
    String organizationId,
  ) async {
    final rows = await _db.customSelect(
      'SELECT * FROM organization_subscriptions WHERE organization_id = ?',
      variables: [Variable<String>(organizationId)],
    ).getSingleOrNull();
    return rows == null ? null : _mapOrganizationSubscriptionRow(rows);
  }

  Future<void> upsertOrganizationSubscription(OrganizationSubscriptionRow row) async {
    await _db.customStatement(
      'INSERT INTO organization_subscriptions '
      '(organization_id, plan_code, status, billing_period, current_period_start, '
      'current_period_end, provider, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(organization_id) DO UPDATE SET '
      'plan_code = excluded.plan_code, status = excluded.status, '
      'billing_period = excluded.billing_period, current_period_start = excluded.current_period_start, '
      'current_period_end = excluded.current_period_end, provider = excluded.provider, '
      'updated_at = excluded.updated_at',
      [
        row.organizationId, row.planCode, row.status, row.billingPeriod,
        row.currentPeriodStart?.toIso8601String(),
        row.currentPeriodEnd?.toIso8601String(),
        row.provider,
        row.createdAt.toIso8601String(), row.updatedAt.toIso8601String(),
      ],
    );
  }

  // ── Row mappers ────────────────────────────────────────────────────────────

  OrganizationRow _mapOrganizationRow(QueryRow row) => OrganizationRow(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        businessType: row.read<String>('business_type'),
        address: row.read<String?>('address'),
        phone: row.read<String?>('phone'),
        ownerUserId: row.read<String?>('owner_user_id'),
        defaultTimezone: row.read<String>('default_timezone'),
        status: row.read<String>('status'),
        trialEndsAt: _tryParse(row.read<String?>('trial_ends_at')),
        createdAt: DateTime.parse(row.read<String>('created_at')),
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
      );

  OrganizationMemberRow _mapOrganizationMemberRow(QueryRow row) =>
      OrganizationMemberRow(
        organizationId: row.read<String>('organization_id'),
        userId: row.read<String>('user_id'),
        role: row.read<String>('role'),
        status: row.read<String>('status'),
        createdAt: DateTime.parse(row.read<String>('created_at')),
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
      );

  SubscriptionPlanRow _mapSubscriptionPlanRow(QueryRow row) => SubscriptionPlanRow(
        code: row.read<String>('code'),
        name: row.read<String>('name'),
        monthlyPrice: row.read<double>('monthly_price'),
        yearlyPrice: row.read<double>('yearly_price'),
        currency: row.read<String>('currency'),
        maxProducts: row.read<int?>('max_products'),
        maxMonthlyTransactions: row.read<int?>('max_monthly_transactions'),
        maxBranchesIncluded: row.read<int>('max_branches_included'),
        maxEmployeesPerPaidBranch:
            row.read<int>('max_employees_per_paid_branch'),
        featuresJson: row.read<String>('features_json'),
        isActive: row.read<int>('is_active') == 1,
        createdAt: DateTime.parse(row.read<String>('created_at')),
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
      );

  OrganizationSubscriptionRow _mapOrganizationSubscriptionRow(QueryRow row) =>
      OrganizationSubscriptionRow(
        organizationId: row.read<String>('organization_id'),
        planCode: row.read<String>('plan_code'),
        status: row.read<String>('status'),
        billingPeriod: row.read<String?>('billing_period'),
        currentPeriodStart: _tryParse(row.read<String?>('current_period_start')),
        currentPeriodEnd: _tryParse(row.read<String?>('current_period_end')),
        provider: row.read<String>('provider'),
        createdAt: DateTime.parse(row.read<String>('created_at')),
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
      );

  static DateTime? _tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

// ── Plain Dart data classes (replacing Drift @DataClassName) ────────────────

class OrganizationRow {
  const OrganizationRow({
    required this.id,
    required this.name,
    required this.businessType,
    this.address,
    this.phone,
    this.ownerUserId,
    required this.defaultTimezone,
    required this.status,
    this.trialEndsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String businessType;
  final String? address;
  final String? phone;
  final String? ownerUserId;
  final String defaultTimezone;
  final String status;
  final DateTime? trialEndsAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class OrganizationMemberRow {
  const OrganizationMemberRow({
    required this.organizationId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String organizationId;
  final String userId;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SubscriptionPlanRow {
  const SubscriptionPlanRow({
    required this.code,
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.currency,
    this.maxProducts,
    this.maxMonthlyTransactions,
    required this.maxBranchesIncluded,
    required this.maxEmployeesPerPaidBranch,
    required this.featuresJson,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String code;
  final String name;
  final double monthlyPrice;
  final double yearlyPrice;
  final String currency;
  final int? maxProducts;
  final int? maxMonthlyTransactions;
  final int maxBranchesIncluded;
  final int maxEmployeesPerPaidBranch;
  final String featuresJson;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class OrganizationSubscriptionRow {
  const OrganizationSubscriptionRow({
    required this.organizationId,
    required this.planCode,
    required this.status,
    this.billingPeriod,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    required this.provider,
    required this.createdAt,
    required this.updatedAt,
  });

  final String organizationId;
  final String planCode;
  final String status;
  final String? billingPeriod;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final String provider;
  final DateTime createdAt;
  final DateTime updatedAt;
}
