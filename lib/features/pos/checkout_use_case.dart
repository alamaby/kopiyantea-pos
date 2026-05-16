import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';
import '../../core/pricing/pricing.dart';
import '../../core/utils/result.dart';
import 'cart_state.dart';

// TODO(Phase 6): replace with the authenticated user ID from authProvider.
const String _kFallbackCashierId = '00000000-0000-0000-0000-000000000012';

enum CheckoutError {
  noBranch,
  emptyCart,
  invalidPayment,
  databaseError,
}

class CheckoutResult {
  const CheckoutResult({
    required this.transactionId,
    required this.totals,
    required this.paymentMethod,
    required this.paymentReceived,
    required this.paymentChange,
    required this.timestamp,
  });

  final String transactionId;
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
  });

  final AppDatabase db;
  final Uuid uuid;
  final String cashierId;

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
      (sum, item) => sum + item.priceSnapshot * item.quantity,
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

    final txId = uuid.v7();
    final now = DateTime.now();
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
              ),
            );

        for (final item in cart.items) {
          await db.into(db.transactionItems).insert(
                _buildItemCompanion(txId: txId, item: item),
              );
        }

        for (final mov in movements) {
          await db.into(db.inventoryMovements).insert(mov);
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
  }) {
    return TransactionsCompanion.insert(
      id: txId,
      branchId: branch.id,
      cashierId: cashierId,
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
      clientCreatedAt: now,
    );
  }

  TransactionItemsCompanion _buildItemCompanion({
    required String txId,
    required CartItem item,
  }) {
    return TransactionItemsCompanion.insert(
      id: uuid.v7(),
      transactionId: txId,
      productId: item.product.id,
      nameSnapshot: item.branchProduct.customName ?? item.product.name,
      priceSnapshot: item.priceSnapshot,
      quantity: item.quantity.toDouble(),
      subtotal: item.priceSnapshot * item.quantity,
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
            r.productId.equals(item.product.id) &
            r.branchId.equals(branchId));
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

final checkoutUseCaseProvider = Provider<CheckoutUseCase>(
  (ref) => CheckoutUseCase(db: ref.watch(databaseProvider)),
);
