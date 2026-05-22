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
        'cashier_name_snapshot': cashierNameSnapshot,
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
        'bank_account_id': bankAccountId,
        'bank_account_snapshot': bankAccountSnapshot,
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

// ── FEAT-004 / 005 / 006 / 001 — additional push DTOs ─────────────────────────

extension BranchSyncDto on BranchRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'timezone': timezone,
        'is_active': isActive,
        'tax_percentage': taxPercentage,
        'tax_label': taxLabel,
        'tax_inclusive': taxInclusive,
        'failed_login_lockout_threshold': failedLoginLockoutThreshold,
        'qris_image_url': qrisImageUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

extension InventoryItemSyncDto on InventoryItemRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'branch_id': branchId,
        'name': name,
        'unit': unit.name,
        // cached_stock is server-authoritative; do NOT push it from client.
        'min_stock': minStock,
        'cost_per_unit': costPerUnit,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

extension AppUserSyncDto on AppUserRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'full_name': fullName,
        'global_role': globalRole.name,
        'email': email,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

extension UserBranchAccessSyncDto on UserBranchAccessRow {
  Map<String, dynamic> toSupabaseJson() => {
        'user_id': userId,
        'branch_id': branchId,
        'role_at_branch': roleAtBranch?.name,
      };
}

extension PendingInvitationSyncDto on PendingInvitationRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'global_role': globalRole.name,
        'branch_ids_csv': branchIdsCsv,
        'invited_by': invitedBy,
        'created_at': createdAt.toIso8601String(),
      };
}

extension OptionGroupSyncDto on OptionGroupRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'is_required': isRequired,
        'is_multi_select': isMultiSelect,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

extension OptionSyncDto on OptionRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'group_id': groupId,
        'name': name,
        'price_delta': priceDelta,
        'sort_order': sortOrder,
        'is_default': isDefault,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

extension TransactionItemOptionSyncDto on TransactionItemOptionRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'transaction_item_id': transactionItemId,
        'option_group_name_snapshot': optionGroupNameSnapshot,
        'option_name_snapshot': optionNameSnapshot,
        'price_delta_snapshot': priceDeltaSnapshot,
      };
}

// ── Opsi C — catalog push DTOs ──────────────────────────────────────────────

extension ProductSyncDto on ProductRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'category': category,
        'base_price': basePrice,
        'sku': sku,
        'image_url': imageUrl,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

extension BranchProductSyncDto on BranchProductRow {
  Map<String, dynamic> toSupabaseJson() => {
        'product_id': productId,
        'branch_id': branchId,
        'price_override': priceOverride,
        'is_available': isAvailable,
        'custom_name': customName,
        'discount_percentage': discountPercentage,
        'discount_valid_until': discountValidUntil?.toIso8601String(),
      };
}

extension ProductRecipeSyncDto on ProductRecipeRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'product_id': productId,
        'branch_id': branchId,
        'inventory_item_id': inventoryItemId,
        'quantity_required': quantityRequired,
      };
}

extension CategorySyncDto on CategoryRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'sort_order': sortOrder,
        'color': color,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

CategoriesCompanion categoryFromJson(Map<String, dynamic> json) =>
    CategoriesCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: Value(json['sort_order'] as int? ?? 0),
      color: Value(json['color'] as int?),
      isActive: Value(json['is_active'] as bool? ?? true),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

extension BankAccountSyncDto on BankAccountRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_holder': accountHolder,
        'display_order': displayOrder,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

BankAccountsCompanion bankAccountFromJson(Map<String, dynamic> json) =>
    BankAccountsCompanion.insert(
      id: json['id'] as String,
      bankName: json['bank_name'] as String,
      accountNumber: json['account_number'] as String,
      accountHolder: json['account_holder'] as String,
      displayOrder: Value(json['display_order'] as int? ?? 0),
      isActive: Value(json['is_active'] as bool? ?? true),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

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
      email: Value(json['email'] as String?),
      isActive: Value(json['is_active'] as bool? ?? true),
      failedLoginCount: Value(json['failed_login_count'] as int? ?? 0),
      lockedUntil: Value(_maybeDate(json['locked_until'])),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

PendingInvitationsCompanion pendingInvitationFromJson(
  Map<String, dynamic> json,
) =>
    PendingInvitationsCompanion.insert(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      globalRole:
          _enumByName(GlobalRole.values, json['global_role'] as String),
      branchIdsCsv: Value(json['branch_ids_csv'] as String? ?? ''),
      invitedBy: Value(json['invited_by'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
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
      qrisImageUrl: Value(json['qris_image_url'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

// ── Master data pull DTOs ─────────────────────────────────────────────────────

ProductsCompanion productFromJson(Map<String, dynamic> json) =>
    ProductsCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      category: Value(json['category'] as String?),
      basePrice: (json['base_price'] as num).toDouble(),
      sku: Value(json['sku'] as String?),
      imageUrl: Value(json['image_url'] as String?),
      isActive: Value(json['is_active'] as bool? ?? true),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

BranchProductsCompanion branchProductFromJson(Map<String, dynamic> json) =>
    BranchProductsCompanion.insert(
      productId: json['product_id'] as String,
      branchId: json['branch_id'] as String,
      priceOverride: Value((json['price_override'] as num?)?.toDouble()),
      isAvailable: Value(json['is_available'] as bool? ?? true),
      customName: Value(json['custom_name'] as String?),
      discountPercentage:
          Value((json['discount_percentage'] as num?)?.toDouble() ?? 0),
      discountValidUntil: Value(_maybeDate(json['discount_valid_until'])),
    );

InventoryItemsCompanion inventoryItemFromJson(Map<String, dynamic> json) =>
    InventoryItemsCompanion.insert(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      name: json['name'] as String,
      unit: _enumByName(StockUnit.values, json['unit'] as String),
      cachedStock: Value((json['cached_stock'] as num?)?.toDouble() ?? 0),
      minStock: Value((json['min_stock'] as num?)?.toDouble() ?? 0),
      costPerUnit: Value((json['cost_per_unit'] as num?)?.toDouble() ?? 0),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

ProductRecipesCompanion productRecipeFromJson(Map<String, dynamic> json) =>
    ProductRecipesCompanion.insert(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      branchId: json['branch_id'] as String,
      inventoryItemId: json['inventory_item_id'] as String,
      quantityRequired: (json['quantity_required'] as num).toDouble(),
    );

CustomersCompanion customerFromJson(Map<String, dynamic> json) =>
    CustomersCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: Value(json['phone'] as String?),
      email: Value(json['email'] as String?),
      loyaltyPoints: Value(json['loyalty_points'] as int? ?? 0),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

TransactionsCompanion transactionFromJson(Map<String, dynamic> json) =>
    TransactionsCompanion.insert(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      cashierId: json['cashier_id'] as String,
      cashierNameSnapshot:
          Value(json['cashier_name_snapshot'] as String?),
      customerId: Value(json['customer_id'] as String?),
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount:
          Value((json['discount_amount'] as num?)?.toDouble() ?? 0),
      taxAmount: Value((json['tax_amount'] as num?)?.toDouble() ?? 0),
      total: (json['total'] as num).toDouble(),
      taxPercentageSnapshot:
          (json['tax_percentage_snapshot'] as num).toDouble(),
      taxLabelSnapshot: json['tax_label_snapshot'] as String,
      taxInclusiveSnapshot: json['tax_inclusive_snapshot'] as bool,
      paymentMethod: _enumByName(
        PaymentMethod.values,
        json['payment_method'] as String,
      ),
      paymentReceived: Value((json['payment_received'] as num?)?.toDouble()),
      paymentChange: Value((json['payment_change'] as num?)?.toDouble()),
      status: _enumByName(
        TransactionStatus.values,
        json['status'] as String,
      ),
      voidedByTransactionId:
          Value(json['voided_by_transaction_id'] as String?),
      voidReason: Value(json['void_reason'] as String?),
      bankAccountId: Value(json['bank_account_id'] as String?),
      bankAccountSnapshot: Value(json['bank_account_snapshot'] as String?),
      clientCreatedAt: DateTime.parse(json['client_created_at'] as String),
      serverReceivedAt: Value(_maybeDate(json['server_received_at'])),
    );

TransactionItemsCompanion transactionItemFromJson(
  Map<String, dynamic> json,
) =>
    TransactionItemsCompanion.insert(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      productId: json['product_id'] as String,
      nameSnapshot: json['name_snapshot'] as String,
      priceSnapshot: (json['price_snapshot'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      notes: Value(json['notes'] as String?),
    );

InventoryMovementsCompanion inventoryMovementFromJson(
  Map<String, dynamic> json,
) =>
    InventoryMovementsCompanion.insert(
      id: json['id'] as String,
      inventoryItemId: json['inventory_item_id'] as String,
      branchId: json['branch_id'] as String,
      movementType: _enumByName(
        MovementType.values,
        json['movement_type'] as String,
      ),
      deltaSigned: (json['delta_signed'] as num).toDouble(),
      referenceId: Value(json['reference_id'] as String?),
      notes: Value(json['notes'] as String?),
      createdBy: Value(json['created_by'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

ReceiptSettingsCompanion receiptSettingFromJson(Map<String, dynamic> json) =>
    ReceiptSettingsCompanion.insert(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      headerText: Value(json['header_text'] as String?),
      footerText: Value(json['footer_text'] as String?),
      logoUrl: Value(json['logo_url'] as String?),
      logoPosition: Value(json['logo_position'] as String? ?? 'top'),
      paperWidthMm: Value(json['paper_width_mm'] as int? ?? 58),
      showLogo: Value(json['show_logo'] as bool? ?? false),
      showCashierName: Value(json['show_cashier_name'] as bool? ?? true),
      printQrisOnReceipt:
          Value(json['print_qris_on_receipt'] as bool? ?? false),
      locale: Value(json['locale'] as String? ?? 'id_ID'),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
