import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/pricing/pricing.dart';
import 'cart_state.dart';

part 'cart_provider.g.dart';

@riverpod
class CartNotifier extends _$CartNotifier {
  @override
  CartState build() => const CartState();

  // ── Branch / customer ───────────────────────────────────────────────────────

  void setBranch(BranchRow branch) => state = state.copyWith(branch: branch);

  void setCustomer(CustomerRow? customer) =>
      state = state.copyWith(customer: customer);

  // ── Items ───────────────────────────────────────────────────────────────────

  void addItem({
    required ProductRow product,
    required BranchProductRow branchProduct,
    String? notes,
    List<CartItemOption> selectedOptions = const [],
  }) {
    final snapshot = effectiveUnitPrice(
      basePrice: product.basePrice,
      priceOverride: branchProduct.priceOverride,
      discountPercentage: branchProduct.discountPercentage,
      discountValidUntil: branchProduct.discountValidUntil,
      now: DateTime.now(),
    );

    // Two lines are mergeable only if their product, branch, notes AND
    // selected option set all match — different modifier choices live on
    // their own line.
    final optionsKey = _optionsKey(selectedOptions);
    final idx = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          i.branchProduct.branchId == branchProduct.branchId &&
          i.notes == notes &&
          _optionsKey(i.selectedOptions) == optionsKey,
    );

    if (idx >= 0) {
      _replaceAt(idx, state.items[idx].copyWith(quantity: state.items[idx].quantity + 1));
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItem(
          product: product,
          branchProduct: branchProduct,
          priceSnapshot: snapshot,
          quantity: 1,
          notes: notes,
          selectedOptions: selectedOptions,
        ),
      ]);
    }
  }

  /// Stable key for option-set equality. Sorts by optionId so order-of-tap
  /// in the picker doesn't break merging.
  String _optionsKey(List<CartItemOption> opts) {
    final ids = opts.map((o) => o.optionId).toList()..sort();
    return ids.join('|');
  }

  void incrementQuantity(int index) {
    final current = state.items[index];
    _replaceAt(index, current.copyWith(quantity: current.quantity + 1));
  }

  void decrementQuantity(int index) {
    final current = state.items[index];
    if (current.quantity <= 1) {
      removeItem(index);
    } else {
      _replaceAt(index, current.copyWith(quantity: current.quantity - 1));
    }
  }

  void updateNotes(int index, String? notes) {
    _replaceAt(index, state.items[index].copyWith(notes: notes));
  }

  /// Replace the modifier selections for the line at [index] (FEAT-001
  /// tap-to-edit). If another line in the cart now has the exact same
  /// (product, branch, notes, options) tuple, the two lines are merged.
  void updateOptions(int index, List<CartItemOption> options) {
    final current = state.items[index];
    final updated = current.copyWith(selectedOptions: options);
    final newKey = _optionsKey(options);
    final mergeIdx = state.items.indexWhere((other) {
      final i = state.items.indexOf(other);
      return i != index &&
          other.product.id == current.product.id &&
          other.branchProduct.branchId == current.branchProduct.branchId &&
          other.notes == current.notes &&
          _optionsKey(other.selectedOptions) == newKey;
    });
    if (mergeIdx >= 0) {
      final merged = state.items[mergeIdx].copyWith(
        quantity: state.items[mergeIdx].quantity + current.quantity,
      );
      final items = [...state.items];
      // Remove edited line first; adjust mergeIdx if it sits after.
      items.removeAt(index);
      final adjustedMergeIdx = mergeIdx > index ? mergeIdx - 1 : mergeIdx;
      items[adjustedMergeIdx] = merged;
      state = state.copyWith(items: items);
    } else {
      _replaceAt(index, updated);
    }
  }

  void removeItem(int index) {
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items);
  }

  /// Re-inserts [item] at [index]. Used by the undo snackbar after a delete.
  /// If [index] is beyond the current list, the item is appended.
  void restoreItem(CartItem item, {required int index}) {
    final items = [...state.items];
    if (index >= items.length) {
      items.add(item);
    } else {
      items.insert(index, item);
    }
    state = state.copyWith(items: items);
  }

  void setManualDiscount(double amount) =>
      state = state.copyWith(manualDiscountAmount: amount);

  void clear() => state = CartState(branch: state.branch);

  // ── Computed (read-only views) ──────────────────────────────────────────────

  double get subtotal => state.items.fold(
        0.0,
        (sum, item) => sum + item.lineSubtotal,
      );

  int get itemCount =>
      state.items.fold(0, (sum, item) => sum + item.quantity);

  /// Returns null when no branch is set on the cart.
  TotalsResult? get totals {
    final branch = state.branch;
    if (branch == null) return null;
    return computeTotals(
      subtotal: subtotal,
      manualDiscountAmount: state.manualDiscountAmount,
      taxPercentage: branch.taxPercentage,
      taxInclusive: branch.taxInclusive,
    );
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  void _replaceAt(int idx, CartItem item) {
    final newItems = [...state.items];
    newItems[idx] = item;
    state = state.copyWith(items: newItems);
  }
}
