import 'package:drift/drift.dart';

import '../../domain/enums.dart';

/// SaaS tenant boundary. Each business (e.g. "Kopiyantea", "Cafe XYZ")
/// is one organization. Data is scoped per org via [organization_id].
///
/// TD-001 resolved 2026-09-21:Drift 2.21+ codegen works; table registered
/// in [@DriftDatabase] since M4 hardening sprint.
@DataClassName('OrganizationRow')
class Organizations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get businessType => text()
      .withDefault(const Constant('generic'))
      .map(const EnumNameConverter<BusinessType>(BusinessType.values))();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get defaultTimezone =>
      text().withDefault(const Constant('Asia/Jakarta'))();
  TextColumn get status => text()
      .withDefault(const Constant('active'))
      .map(const EnumNameConverter<OrganizationStatus>(OrganizationStatus.values))();
  DateTimeColumn get trialEndsAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Membership + role scoped per organization. Replaces [GlobalRole] as the
/// SaaS authorization source.
///
/// TD-001 resolved 2026-09-21 — registered in [@DriftDatabase].
@DataClassName('OrganizationMemberRow')
class OrganizationMembers extends Table {
  TextColumn get organizationId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text().map(
        const EnumNameConverter<OrganizationMemberRole>(
          OrganizationMemberRole.values,
        ),
      )();
  TextColumn get status => text()
      .withDefault(const Constant('active'))
      .map(const EnumNameConverter<OrganizationMemberStatus>(
        OrganizationMemberStatus.values,
      ))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {organizationId, userId};
}

/// Static plan catalog. Seeded once (free, plus). Never deleted.
///
/// TD-001 resolved 2026-09-21 — registered in [@DriftDatabase].
@DataClassName('SubscriptionPlanRow')
class SubscriptionPlans extends Table {
  TextColumn get code => text()
      .map(const EnumNameConverter<SubscriptionPlanCode>(
        SubscriptionPlanCode.values,
      ))();
  TextColumn get name => text()();
  RealColumn get monthlyPrice => real().withDefault(const Constant(0))();
  RealColumn get yearlyPrice => real().withDefault(const Constant(0))();
  TextColumn get currency =>
      text().withDefault(const Constant('IDR'))();
  IntColumn get maxProducts => integer().nullable()();
  IntColumn get maxMonthlyTransactions => integer().nullable()();
  IntColumn get maxBranchesIncluded =>
      integer().withDefault(const Constant(1))();
  IntColumn get maxEmployeesPerPaidBranch =>
      integer().withDefault(const Constant(0))();
  TextColumn get featuresJson =>
      text().withDefault(const Constant('{}'))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {code};
}

/// Active subscription row per organization (one-to-one).
///
/// TD-001 resolved 2026-09-21 — registered in [@DriftDatabase].
@DataClassName('OrganizationSubscriptionRow')
class OrganizationSubscriptions extends Table {
  TextColumn get organizationId => text()();
  TextColumn get planCode => text()();
  TextColumn get status => text().map(
        const EnumNameConverter<SubscriptionStatus>(
          SubscriptionStatus.values,
        ),
      )();
  TextColumn get billingPeriod => text().nullable()();
  DateTimeColumn get currentPeriodStart => dateTime().nullable()();
  DateTimeColumn get currentPeriodEnd => dateTime().nullable()();
  TextColumn get provider =>
      text().withDefault(const Constant('manual'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {organizationId};
}
