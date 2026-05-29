import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';
import '../../core/utils/result.dart';
import '../auth/auth_provider.dart';

part 'void_transaction_use_case.g.dart';

enum VoidError {
  notFound,
  alreadyVoided,
  notVoidable, // already a void row
  databaseError,
}

const String _kPointReasonEarn = 'earn';
const String _kPointReasonVoidReversal = 'void_reversal';

/// ENH-008 — Void/Refund flow (append-only per ADR-0007).
///
/// Voiding does NOT update the original transaction. Instead it inserts a
/// NEW transaction with `status = voided`, `voidedByTransactionId =
/// originalId`, and mirrored-negative subtotal/discount/tax/total — plus
/// reverse inventory_movements (`MovementType.adjustment`, positive deltas)
/// so cached_stock recovers.
///
/// The void row is itself pushed via the standard transaction outbox path
/// (no new entity type). Existing `_pushTransaction` already includes
/// linked inventory_movements where `reference_id = txId` — for a void
/// row that's our reverse movements.
class VoidTransactionUseCase {
  VoidTransactionUseCase(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  Future<Result<String, VoidError>> voidTx({
    required String originalId,
    String? reason,
    Uuid uuid = const Uuid(),
  }) async {
    final txDao = _ref.read(transactionDaoProvider);
    final original = await txDao.getTransactionById(originalId);
    if (original == null) return const Err(VoidError.notFound);
    if (original.status == TransactionStatus.voided) {
      return const Err(VoidError.notVoidable);
    }
    final existingVoid = await txDao.getVoidForTransaction(originalId);
    if (existingVoid != null) return const Err(VoidError.alreadyVoided);

    final voidId = uuid.v7();
    final now = DateTime.now();
    final actorId = _ref.read(currentUserProvider)?.id ?? original.cashierId;

    // Mirror original line items as negatives. UI/reports stay consistent —
    // sum of (completed + voided) for a refunded transaction nets to zero.
    final originalItems = await txDao.getItemsForTransaction(originalId);
    final pointLedgerDao = _ref.read(customerPointLedgerDaoProvider);
    final earnedPointLedger = original.customerId == null
        ? null
        : await pointLedgerDao.getForTransactionReason(
            transactionId: originalId,
            reason: _kPointReasonEarn,
          );
    final existingPointReversal = original.customerId == null
        ? null
        : await pointLedgerDao.getForTransactionReason(
            transactionId: originalId,
            reason: _kPointReasonVoidReversal,
          );
    final pointsToReverse =
        existingPointReversal == null ? earnedPointLedger?.pointsDelta ?? 0 : 0;
    final pointReversalId = pointsToReverse > 0 ? uuid.v7() : null;

    // Reverse inventory movements: positive deltas (opposite sign of the
    // original sale movements). We re-query original movements by
    // reference_id rather than recomputing from recipes — recipes can be
    // edited between checkout and void, and the original movement is the
    // source of truth for what was deducted.
    final originalMovements = await (_db.select(_db.inventoryMovements)
          ..where((m) => m.referenceId.equals(originalId)))
        .get();

    try {
      await _db.transaction(() async {
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: voidId,
                branchId: original.branchId,
                cashierId: actorId,
                customerId: Value(original.customerId),
                subtotal: -original.subtotal,
                discountAmount: Value(-original.discountAmount),
                taxAmount: Value(-original.taxAmount),
                total: -original.total,
                taxPercentageSnapshot: original.taxPercentageSnapshot,
                taxLabelSnapshot: original.taxLabelSnapshot,
                taxInclusiveSnapshot: original.taxInclusiveSnapshot,
                paymentMethod: original.paymentMethod,
                paymentReceived: Value(
                  original.paymentReceived == null
                      ? null
                      : -original.paymentReceived!,
                ),
                paymentChange: Value(
                  original.paymentChange == null
                      ? null
                      : -original.paymentChange!,
                ),
                status: TransactionStatus.voided,
                voidedByTransactionId: Value(originalId),
                voidReason:
                    Value(reason == null || reason.isEmpty ? null : reason),
                clientCreatedAt: now,
              ),
            );

        // Mirror items as negative quantity/subtotal so the void row prints
        // correctly on a refund receipt.
        for (final it in originalItems) {
          await _db.into(_db.transactionItems).insert(
                TransactionItemsCompanion.insert(
                  id: uuid.v7(),
                  transactionId: voidId,
                  productId: it.productId,
                  nameSnapshot: it.nameSnapshot,
                  priceSnapshot: it.priceSnapshot,
                  quantity: -it.quantity,
                  subtotal: -it.subtotal,
                  notes: Value(it.notes),
                ),
              );
        }

        // Reverse inventory: positive delta = stock returned to shelf.
        for (final mov in originalMovements) {
          await _db.into(_db.inventoryMovements).insert(
                InventoryMovementsCompanion.insert(
                  id: uuid.v7(),
                  inventoryItemId: mov.inventoryItemId,
                  branchId: mov.branchId,
                  movementType: MovementType.adjustment,
                  deltaSigned: -mov.deltaSigned, // flip sign
                  referenceId: Value(voidId),
                  notes: Value('Refund of ${originalId.substring(0, 8)}'),
                  createdBy: Value(actorId),
                  createdAt: now,
                ),
              );
          // Update cached_stock to converge locally (same pattern as
          // CheckoutUseCase). Server trigger 008 mirrors this server-side.
          await _db.customUpdate(
            'UPDATE inventory_items SET cached_stock = cached_stock + ? '
            'WHERE id = ?',
            variables: [
              Variable<double>(-mov.deltaSigned),
              Variable<String>(mov.inventoryItemId),
            ],
            updates: {_db.inventoryItems},
          );
        }

        if (original.customerId != null &&
            pointsToReverse > 0 &&
            pointReversalId != null) {
          await _db.into(_db.customerPointLedgers).insert(
                CustomerPointLedgersCompanion.insert(
                  id: pointReversalId,
                  customerId: original.customerId!,
                  transactionId: Value(originalId),
                  pointsDelta: -pointsToReverse,
                  reason: _kPointReasonVoidReversal,
                  createdAt: now,
                ),
              );
          await _db.customUpdate(
            'UPDATE customers '
            'SET loyalty_points = MAX(0, loyalty_points - ?), updated_at = ? '
            'WHERE id = ?',
            variables: [
              Variable<int>(pointsToReverse),
              Variable<DateTime>(now),
              Variable<String>(original.customerId!),
            ],
            updates: {_db.customers},
          );
        }

        // Outbox push — rides the standard transaction path.
        await _db.into(_db.outboxItems).insert(
              OutboxItemsCompanion.insert(
                id: uuid.v7(),
                entityType: OutboxEntityType.transaction,
                payload: jsonEncode({
                  'kind': 'transaction',
                  'id': voidId,
                  'branchId': original.branchId,
                  'voidOf': originalId,
                }),
                createdAt: now,
              ),
            );
        if (pointReversalId != null) {
          await _db.into(_db.outboxItems).insert(
                OutboxItemsCompanion.insert(
                  id: uuid.v7(),
                  entityType: OutboxEntityType.customerPointLedger,
                  payload: jsonEncode({
                    'kind': 'customer_point_ledger',
                    'id': pointReversalId,
                    'transactionId': originalId,
                    'customerId': original.customerId,
                    'reason': _kPointReasonVoidReversal,
                  }),
                  createdAt: now,
                ),
              );
        }
      });
      return Ok(voidId);
    } catch (_) {
      return const Err(VoidError.databaseError);
    }
  }
}

final voidTransactionUseCaseProvider = Provider<VoidTransactionUseCase>(
  VoidTransactionUseCase.new,
);

/// Reactive — emits the void row referencing [originalId] when one exists.
/// Used by TransactionDetailScreen to flip from "Batalkan" button to
/// "Sudah dibatalkan" banner without manual refresh.
@riverpod
Stream<TransactionRow?> voidForTransaction(
  VoidForTransactionRef ref,
  String originalId,
) {
  return ref.watch(transactionDaoProvider).watchVoidForTransaction(originalId);
}
