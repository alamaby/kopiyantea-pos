import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/features/pos/cart_provider.dart';
import 'package:kopiyantea_pos/features/pos/cart_state.dart';

/// Unit tests for [CartNotifier] — exercises mutations without touching Drift.
/// Rows are constructed via their plain data-class constructors.
void main() {
  late ProviderContainer container;
  late CartNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(cartNotifierProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('initial state', () {
    test('empty cart, no branch, no discount', () {
      final s = container.read(cartNotifierProvider);
      expect(s.items, isEmpty);
      expect(s.branch, isNull);
      expect(s.manualDiscountAmount, 0.0);
      expect(notifier.subtotal, 0.0);
      expect(notifier.itemCount, 0);
      expect(notifier.totals, isNull,
          reason: 'totals is null until a branch is set');
    });
  });

  group('setBranch / setCustomer / setBankAccount', () {
    test('setBranch makes totals computable', () {
      notifier.setBranch(_branch());
      expect(notifier.totals, isNotNull);
      // Empty cart → all zeros, but the record is non-null.
      expect(notifier.totals!.total, 0.0);
    });

    test('setCustomer + clear keeps branch but drops customer', () {
      notifier.setBranch(_branch());
      notifier.setCustomer(_customer());
      expect(container.read(cartNotifierProvider).customer, isNotNull);
      notifier.clear();
      expect(container.read(cartNotifierProvider).customer, isNull);
      expect(container.read(cartNotifierProvider).branch, isNotNull,
          reason: 'clear keeps the active branch — kasir continues selling');
    });
  });

  group('addItem', () {
    test('adds a new line when cart is empty', () {
      notifier.addItem(product: _product(), branchProduct: _bp());
      final s = container.read(cartNotifierProvider);
      expect(s.items, hasLength(1));
      expect(s.items.first.quantity, 1);
      expect(s.items.first.priceSnapshot, 25000.0);
    });

    test('merges identical product+notes+options into one line (qty++)', () {
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.addItem(product: _product(), branchProduct: _bp());
      final s = container.read(cartNotifierProvider);
      expect(s.items, hasLength(1));
      expect(s.items.first.quantity, 3);
    });

    test('different notes → separate lines', () {
      notifier.addItem(product: _product(), branchProduct: _bp(), notes: 'less ice');
      notifier.addItem(product: _product(), branchProduct: _bp(), notes: 'extra hot');
      expect(container.read(cartNotifierProvider).items, hasLength(2));
    });

    test('different option-sets → separate lines', () {
      notifier.addItem(
        product: _product(),
        branchProduct: _bp(),
        selectedOptions: [_opt(optionId: 'L', priceDelta: 5000)],
      );
      notifier.addItem(
        product: _product(),
        branchProduct: _bp(),
        selectedOptions: [_opt(optionId: 'M', priceDelta: 3000)],
      );
      expect(container.read(cartNotifierProvider).items, hasLength(2));
    });

    test('same option-set in different tap order still merges', () {
      notifier.addItem(
        product: _product(),
        branchProduct: _bp(),
        selectedOptions: [
          _opt(optionId: 'sugar-less'),
          _opt(optionId: 'milk-oat', priceDelta: 5000),
        ],
      );
      notifier.addItem(
        product: _product(),
        branchProduct: _bp(),
        selectedOptions: [
          _opt(optionId: 'milk-oat', priceDelta: 5000),
          _opt(optionId: 'sugar-less'),
        ],
      );
      final s = container.read(cartNotifierProvider);
      expect(s.items, hasLength(1));
      expect(s.items.first.quantity, 2);
    });

    test('applies branch_product priceOverride to snapshot', () {
      notifier.addItem(
        product: _product(basePrice: 30000),
        branchProduct: _bp(priceOverride: 22000),
      );
      expect(
        container.read(cartNotifierProvider).items.first.priceSnapshot,
        22000.0,
      );
    });

    test('applies discount to override (ADR-0011)', () {
      notifier.addItem(
        product: _product(basePrice: 30000),
        branchProduct: _bp(priceOverride: 25000, discountPercentage: 10),
      );
      expect(
        container.read(cartNotifierProvider).items.first.priceSnapshot,
        22500.0,
      );
    });
  });

  group('quantity mutations', () {
    test('incrementQuantity increases qty by 1', () {
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.incrementQuantity(0);
      expect(container.read(cartNotifierProvider).items.first.quantity, 2);
    });

    test('decrementQuantity decreases qty by 1 when > 1', () {
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.addItem(product: _product(), branchProduct: _bp()); // qty=2
      notifier.decrementQuantity(0);
      expect(container.read(cartNotifierProvider).items.first.quantity, 1);
    });

    test('decrementQuantity removes line when qty would drop to 0', () {
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.decrementQuantity(0);
      expect(container.read(cartNotifierProvider).items, isEmpty);
    });
  });

  group('remove / restore', () {
    test('removeItem removes the line at index', () {
      notifier.addItem(
          product: _product(id: 'p1'), branchProduct: _bp(productId: 'p1'));
      notifier.addItem(
          product: _product(id: 'p2'), branchProduct: _bp(productId: 'p2'));
      notifier.removeItem(0);
      final s = container.read(cartNotifierProvider);
      expect(s.items, hasLength(1));
      expect(s.items.first.product.id, 'p2');
    });

    test('restoreItem inserts back at the original index', () {
      notifier.addItem(
          product: _product(id: 'p1'), branchProduct: _bp(productId: 'p1'));
      notifier.addItem(
          product: _product(id: 'p2'), branchProduct: _bp(productId: 'p2'));
      final removed = container.read(cartNotifierProvider).items.first;
      notifier.removeItem(0);
      notifier.restoreItem(removed, index: 0);
      expect(container.read(cartNotifierProvider).items.first.product.id, 'p1');
    });

    test('restoreItem appends when index is past list end', () {
      notifier.addItem(
          product: _product(id: 'p1'), branchProduct: _bp(productId: 'p1'));
      final removed = container.read(cartNotifierProvider).items.first;
      notifier.removeItem(0);
      notifier.restoreItem(removed, index: 99);
      expect(container.read(cartNotifierProvider).items, hasLength(1));
    });
  });

  group('updateOptions merging', () {
    test('editing one line to match another existing line merges them', () {
      // Line 0: no modifier; Line 1: oat-milk +5000
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.addItem(
        product: _product(),
        branchProduct: _bp(),
        selectedOptions: [_opt(optionId: 'milk-oat', priceDelta: 5000)],
      );
      // Edit line 0 to add the same oat-milk option → should merge into line 1.
      notifier.updateOptions(
        0,
        [_opt(optionId: 'milk-oat', priceDelta: 5000)],
      );
      final items = container.read(cartNotifierProvider).items;
      expect(items, hasLength(1));
      expect(items.first.quantity, 2);
    });

    test('editing options without a matching line keeps the same line', () {
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.updateOptions(
        0,
        [_opt(optionId: 'size-L', priceDelta: 5000)],
      );
      final items = container.read(cartNotifierProvider).items;
      expect(items, hasLength(1));
      expect(items.first.selectedOptions.first.optionId, 'size-L');
    });
  });

  group('manual discount + totals', () {
    test('setManualDiscount writes through to state', () {
      notifier.setManualDiscount(7500);
      expect(
          container.read(cartNotifierProvider).manualDiscountAmount, 7500.0);
    });

    test('totals respects branch tax (10% exclusive default)', () {
      notifier.setBranch(_branch());
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.addItem(product: _product(), branchProduct: _bp());
      // 2 × 25000 = 50000 → tax 5000 → total 55000
      final t = notifier.totals!;
      expect(t.subtotal, 50000.0);
      expect(t.taxAmount, 5000.0);
      expect(t.total, 55000.0);
    });

    test('manual discount reduces taxable base', () {
      notifier.setBranch(_branch());
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.setManualDiscount(5000);
      // base = 25000 − 5000 = 20000 → tax 2000 → total 22000
      final t = notifier.totals!;
      expect(t.taxAmount, 2000.0);
      expect(t.total, 22000.0);
    });
  });

  group('clear / restoreState', () {
    test('clear keeps branch but drops everything else', () {
      notifier.setBranch(_branch());
      notifier.addItem(product: _product(), branchProduct: _bp());
      notifier.setManualDiscount(1000);
      notifier.setCustomer(_customer());

      notifier.clear();
      final s = container.read(cartNotifierProvider);
      expect(s.items, isEmpty);
      expect(s.manualDiscountAmount, 0.0);
      expect(s.customer, isNull);
      expect(s.branch, isNotNull);
    });

    test('restoreState replaces entire state atomically', () {
      final restored = CartState(
        branch: _branch(),
        items: [
          CartItem(
            product: _product(),
            branchProduct: _bp(),
            priceSnapshot: 25000,
            quantity: 4,
          ),
        ],
        manualDiscountAmount: 2500,
      );
      notifier.restoreState(restored);
      final s = container.read(cartNotifierProvider);
      expect(s.items.first.quantity, 4);
      expect(s.manualDiscountAmount, 2500.0);
      expect(notifier.itemCount, 4);
    });
  });
}

// ── Builders ──────────────────────────────────────────────────────────────────

BranchRow _branch({
  String id = 'b1',
  double taxPercentage = 10.0,
  bool taxInclusive = false,
}) =>
    BranchRow(
      id: id,
      name: 'Cabang Tes',
      timezone: 'Asia/Jakarta',
      isActive: true,
      taxPercentage: taxPercentage,
      taxLabel: 'PB1',
      taxInclusive: taxInclusive,
      failedLoginLockoutThreshold: 5,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

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

BranchProductRow _bp({
  String branchId = 'b1',
  String productId = 'p1',
  double? priceOverride,
  double discountPercentage = 0,
  DateTime? discountValidUntil,
}) =>
    BranchProductRow(
      productId: productId,
      branchId: branchId,
      isAvailable: true,
      priceOverride: priceOverride,
      discountPercentage: discountPercentage,
      discountValidUntil: discountValidUntil,
    );

CartItemOption _opt({
  String groupId = 'g',
  String optionId = 'o',
  String groupName = 'Group',
  String optionName = 'Opt',
  double priceDelta = 0,
}) =>
    CartItemOption(
      optionGroupId: groupId,
      optionId: optionId,
      groupName: groupName,
      optionName: optionName,
      priceDelta: priceDelta,
    );

CustomerRow _customer() => CustomerRow(
      id: 'c1',
      name: 'Pelanggan',
      loyaltyPoints: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
