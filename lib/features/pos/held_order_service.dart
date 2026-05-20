import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../auth/auth_provider.dart';
import 'cart_state.dart';

part 'held_order_service.g.dart';

/// FEAT-009 — reactive list of held orders for a given branch.
@riverpod
Stream<List<HeldOrderRow>> heldOrdersForBranch(
  HeldOrdersForBranchRef ref,
  String branchId,
) {
  return ref.watch(heldOrderDaoProvider).watchForBranch(branchId);
}

/// Reactive count badge for the POS "Pesanan Tertahan" button.
@riverpod
Stream<int> heldOrdersCount(HeldOrdersCountRef ref, String branchId) {
  return ref
      .watch(heldOrderDaoProvider)
      .watchForBranch(branchId)
      .map((rows) => rows.length);
}

/// Service: serialize a [CartState] into a held-order row, and restore a
/// payload back into a fresh [CartState] (re-fetching product / branch
/// product rows so price/availability changes propagate).
class HeldOrderService {
  HeldOrderService(this._ref);
  final Ref _ref;

  /// Persist [state] as a held order with [label] (table # or customer name).
  Future<void> hold({
    required CartState state,
    required String label,
  }) async {
    final branch = state.branch;
    if (branch == null) {
      throw StateError('Cannot hold a cart without a branch');
    }
    if (state.items.isEmpty) {
      throw StateError('Cannot hold an empty cart');
    }

    final payload = jsonEncode(_encodeCart(state));
    final userId = _ref.read(currentUserProvider)?.id;

    await _ref.read(heldOrderDaoProvider).insert(
          HeldOrdersCompanion.insert(
            id: const Uuid().v7(),
            branchId: branch.id,
            label: label,
            payloadJson: payload,
            createdBy: Value(userId),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Restore a held-order [row] into a usable [CartState]. Skips items whose
  /// product or branch_product can no longer be resolved (e.g. soft-deleted)
  /// — those are silently dropped; the rest are kept so the cashier isn't
  /// blocked.
  Future<CartState?> restore(HeldOrderRow row) async {
    final catalogDao = _ref.read(catalogDaoProvider);
    final branchDao = _ref.read(branchDaoProvider);
    final customerDao = _ref.read(customerDaoProvider);

    final branch = await branchDao.getBranchById(row.branchId);
    if (branch == null) return null;

    final decoded = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final itemsJson = (decoded['items'] as List).cast<Map<String, dynamic>>();

    final items = <CartItem>[];
    for (final j in itemsJson) {
      final product = await catalogDao.getProductById(j['productId'] as String);
      final bp = await catalogDao.getBranchProduct(
        j['productId'] as String,
        row.branchId,
      );
      if (product == null || bp == null) continue;
      items.add(CartItem(
        product: product,
        branchProduct: bp,
        priceSnapshot: (j['priceSnapshot'] as num).toDouble(),
        quantity: j['quantity'] as int,
        notes: j['notes'] as String?,
        selectedOptions: ((j['options'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((o) => CartItemOption(
                  optionGroupId: o['optionGroupId'] as String,
                  optionId: o['optionId'] as String,
                  groupName: o['groupName'] as String,
                  optionName: o['optionName'] as String,
                  priceDelta: (o['priceDelta'] as num).toDouble(),
                ))
            .toList(),
      ));
    }

    final customerId = decoded['customerId'] as String?;
    final customer =
        customerId == null ? null : await customerDao.getById(customerId);

    return CartState(
      items: items,
      manualDiscountAmount:
          (decoded['manualDiscountAmount'] as num?)?.toDouble() ?? 0.0,
      branch: branch,
      customer: customer,
    );
  }

  Future<void> discard(String heldOrderId) =>
      _ref.read(heldOrderDaoProvider).deleteById(heldOrderId);

  /// Drop held orders older than [maxAge]. Called once at app startup.
  Future<int> pruneOlderThan(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    return _ref.read(heldOrderDaoProvider).deleteOlderThan(cutoff);
  }

  Map<String, dynamic> _encodeCart(CartState state) => {
        'manualDiscountAmount': state.manualDiscountAmount,
        'customerId': state.customer?.id,
        'items': [
          for (final i in state.items)
            {
              'productId': i.product.id,
              'priceSnapshot': i.priceSnapshot,
              'quantity': i.quantity,
              'notes': i.notes,
              'options': [
                for (final o in i.selectedOptions)
                  {
                    'optionGroupId': o.optionGroupId,
                    'optionId': o.optionId,
                    'groupName': o.groupName,
                    'optionName': o.optionName,
                    'priceDelta': o.priceDelta,
                  },
              ],
            },
        ],
      };
}

final heldOrderServiceProvider = Provider<HeldOrderService>(
  HeldOrderService.new,
);
