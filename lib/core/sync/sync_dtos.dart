
import 'dart:convert';

import '../database/daos/organization_dao.dart';

// ── SaaS / Multi-tenant DTOs (FEAT-002) ─────────────────────────────────────

// Push DTOs

extension OrganizationSyncDto on OrganizationRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'business_type': businessType,
        'address': address,
        'phone': phone,
        'owner_user_id': ownerUserId,
        'default_timezone': defaultTimezone,
        'status': status,
        'trial_ends_at': trialEndsAt != null ? _toSupabaseTimestamp(trialEndsAt!) : null,
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
      };
}

extension OrganizationMemberSyncDto on OrganizationMemberRow {
  Map<String, dynamic> toSupabaseJson() => {
        'organization_id': organizationId,
        'user_id': userId,
        'role': role,
        'status': status,
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
      };
}

// Pull DTOs

OrganizationRow organizationFromJson(Map<String, dynamic> json) =>
    OrganizationRow(
      id: json['id'] as String,
      name: json['name'] as String,
      businessType: json['business_type'] as String? ?? 'generic',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      ownerUserId: json['owner_user_id'] as String?,
      defaultTimezone: json['default_timezone'] as String? ?? 'Asia/Jakarta',
      status: json['status'] as String? ?? 'active',
      trialEndsAt: _fromSupabaseTimestampNullable(json['trial_ends_at']),
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

OrganizationMemberRow organizationMemberFromJson(Map<String, dynamic> json) =>
    OrganizationMemberRow(
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      status: json['status'] as String? ?? 'active',
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

SubscriptionPlanRow subscriptionPlanFromJson(Map<String, dynamic> json) =>
    SubscriptionPlanRow(
      code: json['code'] as String,
      name: json['name'] as String,
      monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ?? 0,
      yearlyPrice: (json['yearly_price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'IDR',
      maxProducts: json['max_products'] as int?,
      maxMonthlyTransactions: json['max_monthly_transactions'] as int?,
      maxBranchesIncluded: json['max_branches_included'] as int? ?? 1,
      maxEmployeesPerPaidBranch:
          json['max_employees_per_paid_branch'] as int? ?? 0,
      featuresJson: json['features'] != null
          ? jsonEncode(json['features'])
          : '{}',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

OrganizationSubscriptionRow organizationSubscriptionFromJson(
        Map<String, dynamic> json) =>
    OrganizationSubscriptionRow(
      organizationId: json['organization_id'] as String,
      planCode: json['plan_code'] as String,
      status: json['status'] as String,
      billingPeriod: json['billing_period'] as String?,
      currentPeriodStart: _fromSupabaseTimestampNullable(
          json['current_period_start']),
      currentPeriodEnd:
          _fromSupabaseTimestampNullable(json['current_period_end']),
      provider: json['provider'] as String? ?? 'manual',
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

DateTime? _fromSupabaseTimestampNullable(dynamic value) {
  if (value == null) return null;
  return tryParseDateTime(value.toString());
}

DateTime _fromSupabaseTimestamp(dynamic value) =>
    tryParseDateTime(value.toString()) ?? DateTime.now();

String _toSupabaseTimestamp(DateTime value) => value.toIso8601String();

DateTime? tryParseDateTime(String value) => DateTime.tryParse(value);
