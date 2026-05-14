import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/domain/branch.dart';
import '../../core/domain/cart.dart';
import '../../core/domain/customer.dart';
import '../../core/domain/product.dart';
import '../../core/pricing/pricing.dart';

part 'cart_provider.g.dart';

@riverpod
class CartNotifier extends _$CartNotifier {
  @override
  CartState build() => const CartState();

  // ── Catalog ──────────────────────────────────────────────

  void setBranch(Branch branch) => state = state.copyWith(branch: branch);
  void setCustomer(Customer? customer) =>
      state = state.copyWith(customer: customer);

  // ── Items ────────────────────────────────────────────────

  void addItem({
    required Product product,
    required BranchProduct branchProduct,
    String? notes,
  }) {
    final snapshot = effectiveUnitPrice(
      basePrice: product.basePrice,
      priceOverride: branchProduct.priceOverride,
      discountPercentage: branchProduct.discountPercentage,
      discountValidUntil: branchProduct.discountValidUntil,
      now: DateTime.now(),
    );

    final idx = state.items.indexWhere(
      (i) =>
          i.product.id == product.id &&
          i.branchProduct.branchId == branchProduct.branchId &&
          i.notes == notes,
    );

    if (idx >= 0) {
      final updated = state.items[idx]
          .copyWith(quantity: state.items[idx].quantity + 1);
      state = state.copyWith(
        items: [...state.items..[idx] = updated],
      );
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            product: product,
            branchProduct: branchProduct,
            priceSnapshot: snapshot,
            quantity: 1,
            notes: notes,
          ),
        ],
      );
    }
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      removeItem(index);
      return;
    }
    final updated = state.items[index].copyWith(quantity: quantity);
    state = state.copyWith(items: [...state.items..[index] = updated]);
  }

  void removeItem(int index) {
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items);
  }

  void setManualDiscount(double amount) =>
      state = state.copyWith(manualDiscountAmount: amount);

  void clear() => state = const CartState();

  // ── Computed ─────────────────────────────────────────────

  double get subtotal => state.items.fold(
        0.0,
        (sum, item) => sum + item.priceSnapshot * item.quantity,
      );

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
}
