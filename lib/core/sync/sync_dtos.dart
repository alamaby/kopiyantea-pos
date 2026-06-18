import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import '../database/daos/organization_dao.dart';
import '../database/daos/usage_counter_dao.dart';
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
        'transaction_number': transactionNumber,
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
        'client_created_at': _toSupabaseTimestamp(clientCreatedAt),
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
        'created_at': _toSupabaseTimestamp(createdAt),
      };
}

extension CustomerSyncDto on CustomerRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'loyalty_points': loyaltyPoints,
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
      };
}

extension CustomerPointLedgerSyncDto on CustomerPointLedgerRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'customer_id': customerId,
        'transaction_id': transactionId,
        'points_delta': pointsDelta,
        'reason': reason,
        'created_at': _toSupabaseTimestamp(createdAt),
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
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
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
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
      };
}

extension AppUserSyncDto on AppUserRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'full_name': fullName,
        'global_role': globalRole.name,
        'email': email,
        'is_active': isActive,
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
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
        'created_at': _toSupabaseTimestamp(createdAt),
      };
}

extension OptionGroupSyncDto on OptionGroupRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'is_required': isRequired,
        'is_multi_select': isMultiSelect,
        'sort_order': sortOrder,
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
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
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
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

extension ReceiptSettingSyncDto on ReceiptSettingRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'branch_id': branchId,
        'header_text': headerText,
        'footer_text': footerText,
        'logo_url': logoUrl,
        'paper_width_mm': paperWidthMm,
        'locale': locale,
        'show_logo': showLogo,
        'logo_position': logoPosition,
        'show_cashier_name': showCashierName,
        'show_customer_name': showCustomerName,
        'show_branch_name': showBranchName,
        'show_loyalty_points': showLoyaltyPoints,
        'print_qris_on_receipt': printQrisOnReceipt,
        'updated_at': _toSupabaseTimestamp(updatedAt),
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
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
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
        'discount_valid_until': discountValidUntil == null
            ? null
            : _toSupabaseTimestamp(discountValidUntil!),
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
        'color': color == null ? null : color! & 0x00FFFFFF,
        'is_active': isActive,
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
      };
}

int? _categoryRgb24(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toInt() & 0x00FFFFFF;
  if (raw is! String) return null;

  var text = raw.trim();
  if (text.isEmpty) return null;

  final radix = text.startsWith('#') ||
          text.startsWith('0x') ||
          text.startsWith('0X') ||
          RegExp(r'[a-fA-F]').hasMatch(text)
      ? 16
      : 10;
  if (text.startsWith('#')) text = text.substring(1);
  if (text.startsWith('0x') || text.startsWith('0X')) {
    text = text.substring(2);
  }

  final parsed = int.tryParse(text, radix: radix);
  return parsed == null ? null : parsed & 0x00FFFFFF;
}

CategoriesCompanion categoryFromJson(Map<String, dynamic> json) =>
    CategoriesCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: Value(json['sort_order'] as int? ?? 0),
      color: Value(_categoryRgb24(json['color'])),
      isActive: Value(json['is_active'] as bool? ?? true),
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

extension BankAccountSyncDto on BankAccountRow {
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_holder': accountHolder,
        'display_order': displayOrder,
        'is_active': isActive,
        'created_at': _toSupabaseTimestamp(createdAt),
        'updated_at': _toSupabaseTimestamp(updatedAt),
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
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

// ── Pull DTOs (JSON → Drift Companion) ────────────────────────────────────────

T _enumByName<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((v) => v.name == name);

String _toSupabaseTimestamp(DateTime value) => value.toUtc().toIso8601String();

DateTime _fromSupabaseTimestamp(Object? raw) {
  if (raw == null) {
    throw const FormatException('Supabase timestamp cannot be null');
  }
  final value = raw is DateTime ? raw : DateTime.parse(raw as String);
  return value.toLocal();
}

DateTime? _maybeDate(Object? raw) =>
    raw == null ? null : _fromSupabaseTimestamp(raw);

AppUsersCompanion appUserFromJson(Map<String, dynamic> json) =>
    AppUsersCompanion.insert(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      globalRole: _enumByName(GlobalRole.values, json['global_role'] as String),
      email: Value(json['email'] as String?),
      isActive: Value(json['is_active'] as bool? ?? true),
      failedLoginCount: Value(json['failed_login_count'] as int? ?? 0),
      lockedUntil: Value(_maybeDate(json['locked_until'])),
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

PendingInvitationsCompanion pendingInvitationFromJson(
  Map<String, dynamic> json,
) =>
    PendingInvitationsCompanion.insert(
      id: json['id'] as String,
      email: Value(json['email'] as String?),
      fullName: Value(json['full_name'] as String?),
      globalRole: _enumByName(GlobalRole.values, json['global_role'] as String),
      branchIdsCsv: Value(json['branch_ids_csv'] as String? ?? ''),
      invitedBy: Value(json['invited_by'] as String?),
      createdAt: _fromSupabaseTimestamp(json['created_at']),
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
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
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
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
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
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

ProductRecipesCompanion productRecipeFromJson(Map<String, dynamic> json) =>
    ProductRecipesCompanion.insert(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      branchId: json['branch_id'] as String,
      inventoryItemId: json['inventory_item_id'] as String,
      quantityRequired: (json['quantity_required'] as num).toDouble(),
    );

OptionGroupsCompanion optionGroupFromJson(Map<String, dynamic> json) =>
    OptionGroupsCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      isRequired: Value(json['is_required'] as bool? ?? false),
      isMultiSelect: Value(json['is_multi_select'] as bool? ?? false),
      sortOrder: Value(json['sort_order'] as int? ?? 0),
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

MenuOptionsCompanion optionFromJson(Map<String, dynamic> json) =>
    MenuOptionsCompanion.insert(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      priceDelta: Value((json['price_delta'] as num?)?.toDouble() ?? 0),
      sortOrder: Value(json['sort_order'] as int? ?? 0),
      isDefault: Value(json['is_default'] as bool? ?? false),
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

ProductOptionGroupsCompanion productOptionGroupFromJson(
  Map<String, dynamic> json,
) =>
    ProductOptionGroupsCompanion.insert(
      productId: json['product_id'] as String,
      optionGroupId: json['option_group_id'] as String,
    );

CustomersCompanion customerFromJson(Map<String, dynamic> json) =>
    CustomersCompanion.insert(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: Value(json['phone'] as String?),
      email: Value(json['email'] as String?),
      loyaltyPoints: Value(json['loyalty_points'] as int? ?? 0),
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

CustomerPointLedgersCompanion customerPointLedgerFromJson(
  Map<String, dynamic> json,
) =>
    CustomerPointLedgersCompanion.insert(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      transactionId: Value(json['transaction_id'] as String?),
      pointsDelta: (json['points_delta'] as num).toInt(),
      reason: json['reason'] as String,
      createdAt: _fromSupabaseTimestamp(json['created_at']),
    );

TransactionsCompanion transactionFromJson(Map<String, dynamic> json) =>
    TransactionsCompanion.insert(
      id: json['id'] as String,
      transactionNumber: Value(json['transaction_number'] as String?),
      branchId: json['branch_id'] as String,
      cashierId: json['cashier_id'] as String,
      cashierNameSnapshot: Value(json['cashier_name_snapshot'] as String?),
      customerId: Value(json['customer_id'] as String?),
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: Value((json['discount_amount'] as num?)?.toDouble() ?? 0),
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
      voidedByTransactionId: Value(json['voided_by_transaction_id'] as String?),
      voidReason: Value(json['void_reason'] as String?),
      bankAccountId: Value(json['bank_account_id'] as String?),
      bankAccountSnapshot: Value(json['bank_account_snapshot'] as String?),
      clientCreatedAt: _fromSupabaseTimestamp(json['client_created_at']),
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
      createdAt: _fromSupabaseTimestamp(json['created_at']),
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
      showCustomerName: Value(json['show_customer_name'] as bool? ?? true),
      showBranchName: Value(json['show_branch_name'] as bool? ?? true),
      showLoyaltyPoints: Value(json['show_loyalty_points'] as bool? ?? true),
      printQrisOnReceipt:
          Value(json['print_qris_on_receipt'] as bool? ?? false),
      locale: Value(json['locale'] as String? ?? 'id_ID'),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

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
        'trial_ends_at':
            trialEndsAt != null ? _toSupabaseTimestamp(trialEndsAt!) : null,
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
      trialEndsAt: _maybeDate(json['trial_ends_at']),
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
      featuresJson:
          json['features'] != null ? jsonEncode(json['features']) : '{}',
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
      currentPeriodStart: _maybeDate(json['current_period_start']),
      currentPeriodEnd: _maybeDate(json['current_period_end']),
      provider: json['provider'] as String? ?? 'manual',
      createdAt: _fromSupabaseTimestamp(json['created_at']),
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );

// ── Usage Counter DTOs ────────────────────────────────────────────────────

extension UsageCounterSyncDto on UsageCounterRow {
  Map<String, dynamic> toSupabaseJson() => {
        'organization_id': organizationId,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'transaction_count': transactionCount,
        'product_count_snapshot': productCountSnapshot,
        'branch_count_snapshot': branchCountSnapshot,
        'employee_count_snapshot': employeeCountSnapshot,
        'updated_at': _toSupabaseTimestamp(updatedAt),
      };
}

UsageCounterRow usageCounterFromJson(Map<String, dynamic> json) =>
    UsageCounterRow(
      organizationId: json['organization_id'] as String,
      periodStart: _fromSupabaseTimestamp(json['period_start']),
      periodEnd: _fromSupabaseTimestamp(json['period_end']),
      transactionCount: json['transaction_count'] as int? ?? 0,
      productCountSnapshot: json['product_count_snapshot'] as int? ?? 0,
      branchCountSnapshot: json['branch_count_snapshot'] as int? ?? 0,
      employeeCountSnapshot: json['employee_count_snapshot'] as int? ?? 0,
      updatedAt: _fromSupabaseTimestamp(json['updated_at']),
    );
