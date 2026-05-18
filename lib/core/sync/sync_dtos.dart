import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import '../domain/enums.dart';

/// Drift Row ⇄ Supabase JSON serialization for sync.
///
/// Master prompt §2.4 option A: hand-written DTOs that mirror the DDL. A CI
/// test (Phase 7) diffs the schema against these maps.
///
/// snake_case keys match Postgres column names; values pass through Postgres
/// types directly (numeric, boolean, text, timestamptz as ISO-8601 strings).

// ── Push DTOs (Drift Row → JSON) ──────────────────────────────────────────────

extension TransactionSyncDto on TransactionRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'branch_id': branchId,
        'cashier_id': cashierId,
        'customer_id': customerId,
        'subtotal': subtotal,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'total': total,
        'tax_percentage_snapshot': taxPercentageSnapshot,
        'tax_label_snapshot': taxLabelSnapshot,
        'tax_inclusive_snapshot': taxInclusiveSnapshot,
        'payment_method': paymentMethod.name,
        'payment_received': paymentReceived,
        'payment_change': paymentChange,
        'status': status.name,
        'voided_by_transaction_id': voidedByTransactionId,
        'void_reason': voidReason,
        'client_created_at': clientCreatedAt.toIso8601String(),
        // server_received_at is set by Supabase trigger
      };
}

extension TransactionItemSyncDto on TransactionItemRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'transaction_id': transactionId,
        'product_id': productId,
        'name_snapshot': nameSnapshot,
        'price_snapshot': priceSnapshot,
        'quantity': quantity,
        'subtotal': subtotal,
        'notes': notes,
      };
}

extension InventoryMovementSyncDto on InventoryMovementRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'inventory_item_id': inventoryItemId,
        'branch_id': branchId,
        'movement_type': movementType.name,
        'delta_signed': deltaSigned,
        'reference_id': referenceId,
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };
}

extension CustomerSyncDto on CustomerRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'loyalty_points': loyaltyPoints,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ── Pull DTOs (JSON → Drift Companion) ────────────────────────────────────────

T _enumByName<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((v) => v.name == name);

DateTime? _maybeDate(Object? raw) =>
    raw == null ? null : DateTime.parse(raw as String);

AppUsersCompanion appUserFromJson(Map<String, dynamic> json) =>
    AppUsersCompanion.insert(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      globalRole:
          _enumByName(GlobalRole.values, json['global_role'] as String),
      isActive: Value(json['is_active'] as bool? ?? true),
      failedLoginCount: Value(json['failed_login_count'] as int? ?? 0),
      lockedUntil: Value(_maybeDate(json['locked_until'])),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

UserBranchAccessesCompanion userBranchAccessFromJson(
  Map<String, dynamic> json,
) {
  final role = json['role_at_branch'] as String?;
  return UserBranchAccessesCompanion.insert(
    userId: json['user_id'] as String,
    branchId: json['branch_id'] as String,
    roleAtBranch: role == null
        ? const Value.absent()
        : Value(_enumByName(BranchRole.values, role)),
  );
}

BranchesCompanion branchFromJson(Map<String, dynamic> json) =>
    BranchesCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      address: Value(json['address'] as String?),
      phone: Value(json['phone'] as String?),
      timezone: Value(json['timezone'] as String? ?? 'Asia/Jakarta'),
      isActive: Value(json['is_active'] as bool? ?? true),
      taxPercentage: Value((json['tax_percentage'] as num).toDouble()),
      taxLabel: Value(json['tax_label'] as String? ?? 'PB1'),
      taxInclusive: Value(json['tax_inclusive'] as bool? ?? false),
      failedLoginLockoutThreshold:
          Value(json['failed_login_lockout_threshold'] as int? ?? 5),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
