import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/features/pos/cart_state.dart';

/// ENH-013 — covers `CartItemPricing` extension (effectiveUnitPrice,
/// lineSubtotal, optionDelta) for FEAT-001 modifier math.
///
/// These tests don't touch Drift — they build [CartItem] / [ProductRow] /
/// [BranchProductRow] directly via their data-class constructors. We're
/// validating pure arithmetic on the cart line, not persistence.
void main() {
  ProductRow _product({
    String id = 'p1',
    String name = 'Latte',
    double basePrice = 25000,
  }) =>
      ProductRow(
        id: id,
        name: name,
        basePrice: basePrice,
        isActive: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  BranchProductRow _bp({String branchId = 'b1', String productId = 'p1'}) =>
      BranchProductRow(
        productId: productId,
        branchId: branchId,
        isAvailable: true,
        discountPercentage: 0,
      );

  CartItemOption _opt({
    String groupId = 'g',
    String optionId = 'o',
    String groupName = 'Sugar',
    String optionName = 'Less',
    double priceDelta = 0,
  }) =>
      CartItemOption(
        optionGroupId: groupId,
        optionId: optionId,
        groupName: groupName,
        optionName: optionName,
        priceDelta: priceDelta,
      );

  group('CartItem.optionDelta', () {
    test('returns 0 when no options selected', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25000,
        quantity: 1,
      );
      expect(item.optionDelta, 0.0);
    });

    test('sums positive deltas across multiple groups', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25000,
        quantity: 1,
        selectedOptions: [
          _opt(groupId: 'size', optionId: 'L', priceDelta: 5000),
          _opt(groupId: 'shot', optionId: 'x2', priceDelta: 7000),
        ],
      );
      expect(item.optionDelta, 12000.0);
    });

    test('handles zero-delta options (no upcharge)', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25000,
        quantity: 2,
        selectedOptions: [
          _opt(groupId: 'sugar', optionId: 'less', priceDelta: 0),
        ],
      );
      expect(item.optionDelta, 0.0);
      expect(item.effectiveUnitPrice, 25000.0);
    });

    test('mixed zero + paid deltas sum correctly', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25000,
        quantity: 1,
        selectedOptions: [
          _opt(groupId: 'sugar', optionId: 'less', priceDelta: 0),
          _opt(groupId: 'milk', optionId: 'oat', priceDelta: 8000),
        ],
      );
      expect(item.optionDelta, 8000.0);
    });
  });

  group('CartItem.effectiveUnitPrice', () {
    test('equals priceSnapshot when no options', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25000,
        quantity: 1,
      );
      expect(item.effectiveUnitPrice, 25000.0);
    });

    test('adds total option delta to snapshot', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25000,
        quantity: 1,
        selectedOptions: [_opt(priceDelta: 5000)],
      );
      expect(item.effectiveUnitPrice, 30000.0);
    });

    test('snapshot already discounted — modifier still adds full delta', () {
      // priceSnapshot is post-discount per ADR-0011 — modifier delta is
      // applied AFTER discount (no double-discount on the upsell).
      final item = CartItem(
        product: _product(basePrice: 30000),
        branchProduct: _bp(),
        priceSnapshot: 22500, // 30000 with 25% discount
        quantity: 1,
        selectedOptions: [_opt(priceDelta: 5000)],
      );
      expect(item.effectiveUnitPrice, 27500.0);
    });
  });

  group('CartItem.lineSubtotal', () {
    test('= effectiveUnitPrice × quantity', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25000,
        quantity: 3,
        selectedOptions: [_opt(priceDelta: 2000)],
      );
      expect(item.lineSubtotal, 81000.0); // (25000 + 2000) × 3
    });

    test('quantity 0 yields 0 subtotal', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25000,
        quantity: 0,
      );
      expect(item.lineSubtotal, 0.0);
    });

    test('large quantity does not lose precision (integer math)', () {
      final item = CartItem(
        product: _product(),
        branchProduct: _bp(),
        priceSnapshot: 25500,
        quantity: 100,
        selectedOptions: [_opt(priceDelta: 500)],
      );
      expect(item.lineSubtotal, 2600000.0);
    });
  });

  group('option-set equality (used by addItem merging in CartNotifier)', () {
    test('two items with the same option ids merge regardless of order', () {
      // _optionsKey in CartNotifier sorts by optionId — we reproduce the
      // expected stability here to lock the contract.
      List<String> keyOf(List<CartItemOption> opts) =>
          (opts.map((o) => o.optionId).toList()..sort());

      final a = [
        _opt(groupId: 'sugar', optionId: 'less'),
        _opt(groupId: 'milk', optionId: 'oat'),
      ];
      final b = [
        _opt(groupId: 'milk', optionId: 'oat'),
        _opt(groupId: 'sugar', optionId: 'less'),
      ];
      expect(keyOf(a), equals(keyOf(b)));
    });

    test('disjoint option sets do NOT merge', () {
      List<String> keyOf(List<CartItemOption> opts) =>
          (opts.map((o) => o.optionId).toList()..sort());

      final a = [_opt(groupId: 'sugar', optionId: 'less')];
      final b = [_opt(groupId: 'sugar', optionId: 'normal')];
      expect(keyOf(a), isNot(equals(keyOf(b))));
    });

    test('empty options and one-option items are different lines', () {
      List<String> keyOf(List<CartItemOption> opts) =>
          (opts.map((o) => o.optionId).toList()..sort());

      expect(keyOf(const []), <String>[]);
      expect(keyOf([_opt(optionId: 'x')]), ['x']);
    });
  });
}
