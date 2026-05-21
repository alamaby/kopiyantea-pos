import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/database/app_database.dart';

part 'cart_state.freezed.dart';

/// A selected modifier option attached to a [CartItem] (FEAT-001).
///
/// Stores both the master IDs (for traceability) and immutable snapshot
/// strings — the snapshots are what land in `transaction_item_options` at
/// checkout so receipts survive master renames.
@freezed
class CartItemOption with _$CartItemOption {
  const factory CartItemOption({
    required String optionGroupId,
    required String optionId,
    required String groupName,
    required String optionName,
    required double priceDelta,
  }) = _CartItemOption;
}

/// One line in the POS cart.
///
/// [priceSnapshot] is the base unit price post-discount/override but
/// EXCLUDING modifier deltas. Modifier deltas live in [selectedOptions]
/// and are summed in by `lineSubtotal`/cart totals.
@freezed
class CartItem with _$CartItem {
  const factory CartItem({
    required ProductRow product,
    required BranchProductRow branchProduct,
    required double priceSnapshot,
    required int quantity,
    String? notes,
    @Default([]) List<CartItemOption> selectedOptions,
  }) = _CartItem;
}

extension CartItemPricing on CartItem {
  /// Sum of modifier deltas for one unit.
  double get optionDelta =>
      selectedOptions.fold<double>(0, (s, o) => s + o.priceDelta);

  /// Effective per-unit price (base snapshot + modifier deltas).
  double get effectiveUnitPrice => priceSnapshot + optionDelta;

  /// Subtotal for this line.
  double get lineSubtotal => effectiveUnitPrice * quantity;
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
    /// FEAT-015 — bank account selected at checkout when paying via
    /// Transfer. Carried in cart state (vs as a local CheckoutSheet var)
    /// so it survives sheet dismiss/re-open and so totals UI can display
    /// it. Cleared on `clear()` like everything else.
    BankAccountRow? bankAccount,
  }) = _CartState;
}
