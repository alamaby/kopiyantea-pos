import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/database/app_database.dart';

part 'cart_state.freezed.dart';

/// One line in the POS cart.
///
/// [priceSnapshot] is pre-computed via `effectiveUnitPrice` at add-time and
/// mirrors what will be stored in `transaction_items.price_snapshot`.
@freezed
class CartItem with _$CartItem {
  const factory CartItem({
    required ProductRow product,
    required BranchProductRow branchProduct,
    required double priceSnapshot,
    required int quantity,
    String? notes,
  }) = _CartItem;
}

/// Full in-memory POS cart state.
///
/// Totals are computed by [CartNotifier] from this state — never stored here.
@freezed
class CartState with _$CartState {
  const factory CartState({
    @Default([]) List<CartItem> items,
    @Default(0.0) double manualDiscountAmount,
    BranchRow? branch,
    CustomerRow? customer,
  }) = _CartState;
}
