import 'package:freezed_annotation/freezed_annotation.dart';

import 'branch.dart';
import 'customer.dart';
import 'product.dart';

part 'cart.freezed.dart';

/// One line in the POS cart.
///
/// [priceSnapshot] is pre-computed via [effectiveUnitPrice] at add-time and
/// mirrors what will be stored in [TransactionItem.priceSnapshot].
@freezed
class CartItem with _$CartItem {
  const factory CartItem({
    required Product product,
    required BranchProduct branchProduct,
    required double priceSnapshot,
    required int quantity,
    String? notes,
  }) = _CartItem;
}

/// Full in-memory POS cart state.
///
/// Totals (subtotal, tax, total) are computed by [CartNotifier] from this
/// state using [computeTotals]. Do not store derived totals here — they go
/// onto the [Transaction] row at checkout.
@freezed
class CartState with _$CartState {
  const factory CartState({
    @Default([]) List<CartItem> items,
    @Default(0.0) double manualDiscountAmount,
    Branch? branch,
    Customer? customer,
  }) = _CartState;
}
