import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';
import '../../core/pricing/pricing.dart';
import '../../core/utils/result.dart';
import '../auth/auth_provider.dart';
import 'cart_state.dart';

// TODO(Phase 6): replace with the authenticated user ID from authProvider.
const String _kFallbackCashierId = '00000000-0000-0000-0000-000000000012';

enum CheckoutError {
  noBranch,
  emptyCart,
  invalidPayment,

  /// FEAT-015 — Transfer chosen but no bank account selected.
  bankAccountMissing,
  databaseError,
}

class CheckoutResult {
  const CheckoutResult({
    required this.transactionId,
    required this.transactionNumber,
    required this.totals,
    required this.paymentMethod,
    required this.paymentReceived,
    required this.paymentChange,
    required this.timestamp,
  });

  final String transactionId;
  final String transactionNumber;
  final TotalsResult totals;
  final PaymentMethod paymentMethod;
  final double? paymentReceived;
  final double? paymentChange;
  final DateTime timestamp;
}

/// Saves a cart as an immutable [Transaction] with full atomic semantics:
/// transaction row + transaction items + outbox row + inventory movements
/// all commit together or not at all (ADR-0004).
class CheckoutUseCase {
  CheckoutUseCase({
    required this.db,
    this.uuid = const Uuid(),
    this.cashierId = _kFallbackCashierId,
    this.cashierName,
  });

  final AppDatabase db;
  final Uuid uuid;
  final String cashierId;

  /// Snapshot taken at provider construction (logged-in user's full name).
  /// Null for the demo-fallback path; receipt UI falls back to a live
  /// lookup when null.
  final String? cashierName;

  Future<Result<CheckoutResult, CheckoutError>> checkout({
    required CartState cart,
    required PaymentMethod paymentMethod,
    double? paymentReceived,
  }) async {
    final branch = cart.branch;
    if (branch == null) return const Err(CheckoutError.noBranch);
    if (cart.items.isEmpty) return const Err(CheckoutError.emptyCart);

    final subtotal = cart.items.fold<double>(
      0,
      (sum, item) => sum + item.lineSubtotal,
    );
    final totals = computeTotals(
      subtotal: subtotal,
      manualDiscountAmount: cart.manualDiscountAmount,
      taxPercentage: branch.taxPercentage,
      taxInclusive: branch.taxInclusive,
    );

    // Cash payment must cover the total.
    final isCash = paymentMethod == PaymentMethod.cash;
    if (isCash && (paymentReceived == null || paymentReceived < totals.total)) {
      return const Err(CheckoutError.invalidPayment);
    }

    // FEAT-015 — Transfer requires a bank account.
    if (paymentMethod == PaymentMethod.transfer && cart.bankAccount == null) {
      return const Err(CheckoutError.bankAccountMissing);
    }

    final now = DateTime.now();
    final txId = uuid.v7();
    final transactionNumber = await _buildTransactionNumber(branch.id, now);
    final change = isCash ? (paymentReceived! - totals.total) : null;

    final movements = await _buildInventoryMovements(
      cart: cart,
      branchId: branch.id,
      transactionId: txId,
      now: now,
    );

    try {
      await db.transaction(() async {
        await db.into(db.transactions).insert(
              _buildTransactionCompanion(
                txId: txId,
                branch: branch,
                cart: cart,
                totals: totals,
                paymentMethod: paymentMethod,
                paymentReceived: paymentReceived,
                paymentChange: change,
                now: now,
                transactionNumber: transactionNumber,
              ),
            );

        for (final item in cart.items) {
          final itemId = uuid.v7();
          await db.into(db.transactionItems).insert(
                _buildItemCompanion(
                  txId: txId,
                  itemId: itemId,
                  item: item,
                ),
              );
          // FEAT-001 — snapshot each selected modifier into
          // transaction_item_options (append-only, immutable).
          for (final opt in item.selectedOptions) {
            await db.into(db.transactionItemOptions).insert(
                  TransactionItemOptionsCompanion.insert(
                    id: uuid.v7(),
                    transactionItemId: itemId,
                    optionGroupNameSnapshot: opt.groupName,
                    optionNameSnapshot: opt.optionName,
                    priceDeltaSnapshot: opt.priceDelta,
                  ),
                );
          }
        }

        for (final mov in movements) {
          await db.into(db.inventoryMovements).insert(mov);
        }

        // Local cached_stock reconciliation — keeps the offline UI accurate.
        // Source of truth remains the movements table (ADR-0003); Supabase's
        // server trigger does the same arithmetic at sync time, so client
        // and server converge deterministically. `customUpdate` with
        // `updates: {db.inventoryItems}` invalidates the watch streams so
        // the inventory list/detail screens refresh live.
        for (final entry in _aggregateDeltas(movements).entries) {
          await db.customUpdate(
            'UPDATE inventory_items SET cached_stock = cached_stock + ? '
            'WHERE id = ?',
            variables: [
              Variable<double>(entry.value),
              Variable<String>(entry.key),
            ],
            updates: {db.inventoryItems},
          );
        }

        await db.into(db.outboxItems).insert(
              _buildOutboxCompanion(txId: txId, branchId: branch.id, now: now),
            );
      });
    } catch (_) {
      return const Err(CheckoutError.databaseError);
    }

    return Ok(
      CheckoutResult(
        transactionId: txId,
        transactionNumber: transactionNumber,
        totals: totals,
        paymentMethod: paymentMethod,
        paymentReceived: paymentReceived,
        paymentChange: change,
        timestamp: now,
      ),
    );
  }

  // ── Companion builders ──────────────────────────────────────────────────────

  TransactionsCompanion _buildTransactionCompanion({
    required String txId,
    required BranchRow branch,
    required CartState cart,
    required TotalsResult totals,
    required PaymentMethod paymentMethod,
    double? paymentReceived,
    double? paymentChange,
    required DateTime now,
    required String transactionNumber,
  }) {
    final ba = cart.bankAccount;
    final bankSnapshot = ba == null
        ? null
        : '${ba.bankName} ${ba.accountNumber} - ${ba.accountHolder}';
    return TransactionsCompanion.insert(
      id: txId,
      transactionNumber: Value(transactionNumber),
      branchId: branch.id,
      cashierId: cashierId,
      cashierNameSnapshot: Value(cashierName),
      customerId: Value(cart.customer?.id),
      subtotal: totals.subtotal,
      discountAmount: Value(cart.manualDiscountAmount),
      taxAmount: Value(totals.taxAmount),
      total: totals.total,
      taxPercentageSnapshot: branch.taxPercentage,
      taxLabelSnapshot: branch.taxLabel,
      taxInclusiveSnapshot: branch.taxInclusive,
      paymentMethod: paymentMethod,
      paymentReceived: Value(paymentReceived),
      paymentChange: Value(paymentChange),
      status: TransactionStatus.completed,
      bankAccountId: Value(ba?.id),
      bankAccountSnapshot: Value(bankSnapshot),
      clientCreatedAt: now,
    );
  }

  Future<String> _buildTransactionNumber(String branchId, DateTime now) async {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.customSelect(
      'SELECT COUNT(*) AS count FROM transactions '
      'WHERE branch_id = ? '
      'AND voided_by_transaction_id IS NULL '
      'AND client_created_at >= ? '
      'AND client_created_at < ?',
      variables: [
        Variable<String>(branchId),
        Variable<DateTime>(start),
        Variable<DateTime>(end),
      ],
    ).getSingle();
    final queue = result.read<int>('count') + 1;
    return '${_two(now.year % 100)}${_two(now.month)}${_two(now.day)}'
        '${_two(now.hour)}${_two(now.minute)}-${queue.toString().padLeft(3, '0')}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  TransactionItemsCompanion _buildItemCompanion({
    required String txId,
    required String itemId,
    required CartItem item,
  }) {
    // priceSnapshot here = effective per-unit price *including* modifier
    // deltas, so the receipt matches what the customer paid. The per-option
    // breakdown lives in transaction_item_options.
    return TransactionItemsCompanion.insert(
      id: itemId,
      transactionId: txId,
      productId: item.product.id,
      nameSnapshot: item.branchProduct.customName ?? item.product.name,
      priceSnapshot: item.effectiveUnitPrice,
      quantity: item.quantity.toDouble(),
      subtotal: item.lineSubtotal,
      notes: Value(item.notes),
    );
  }

  /// Builds inventory deduction movements based on `product_recipes`.
  /// Reads happen outside the write transaction; movements are pre-baked
  /// then inserted inside the atomic block.
  Future<List<InventoryMovementsCompanion>> _buildInventoryMovements({
    required CartState cart,
    required String branchId,
    required String transactionId,
    required DateTime now,
  }) async {
    final result = <InventoryMovementsCompanion>[];
    for (final item in cart.items) {
      final query = db.select(db.productRecipes)
        ..where((r) =>
            r.productId.equals(item.product.id) & r.branchId.equals(branchId));
      final recipes = await query.get();
      for (final recipe in recipes) {
        result.add(
          InventoryMovementsCompanion.insert(
            id: uuid.v7(),
            inventoryItemId: recipe.inventoryItemId,
            branchId: branchId,
            movementType: MovementType.sale,
            deltaSigned: -recipe.quantityRequired * item.quantity,
            referenceId: Value(transactionId),
            createdBy: Value(cashierId),
            createdAt: now,
          ),
        );
      }
    }
    return result;
  }

  /// Sums signed deltas per inventory item — one item may appear across
  /// multiple cart lines and recipes (e.g. milk in both Latte and Cappuccino).
  Map<String, double> _aggregateDeltas(
    List<InventoryMovementsCompanion> movements,
  ) {
    final out = <String, double>{};
    for (final mov in movements) {
      final itemId = mov.inventoryItemId.value;
      final delta = mov.deltaSigned.value;
      out.update(itemId, (existing) => existing + delta, ifAbsent: () => delta);
    }
    return out;
  }

  OutboxItemsCompanion _buildOutboxCompanion({
    required String txId,
    required String branchId,
    required DateTime now,
  }) {
    // Minimal payload — the sync layer (Phase 6) re-reads the full transaction
    // from local DB at push time. The outbox only needs to know what to push.
    final payload = jsonEncode({
      'kind': 'transaction',
      'id': txId,
      'branchId': branchId,
    });
    return OutboxItemsCompanion.insert(
      id: uuid.v7(),
      entityType: OutboxEntityType.transaction,
      payload: payload,
      createdAt: now,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final checkoutUseCaseProvider = Provider<CheckoutUseCase>((ref) {
  // Prefer the authenticated user's id; fall back to a fixed dev cashier when
  // not authenticated. Production gates checkout behind the auth router
  // redirect, so this path shouldn't fire there.
  final user = ref.watch(currentUserProvider);
  return CheckoutUseCase(
    db: ref.watch(databaseProvider),
    cashierId: user?.id ?? _kFallbackCashierId,
    cashierName: user?.fullName,
  );
});
