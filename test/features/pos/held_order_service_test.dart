import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/database/database_provider.dart';
import 'package:kopiyantea_pos/features/pos/cart_state.dart';
import 'package:kopiyantea_pos/features/pos/held_order_service.dart';

import '../../helpers/test_db.dart';

/// FEAT-009 — HeldOrderService roundtrip + prune logic.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late HeldOrderService service;

  setUp(() async {
    db = AppDatabase.memory();
    await seedMinimal(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    service = container.read(heldOrderServiceProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<CartState> _buildCart({
    int quantity = 2,
    double discount = 0,
    List<CartItemOption> options = const [],
  }) async {
    return CartState(
      branch: await branchRow(db),
      items: [
        CartItem(
          product: await productRow(db),
          branchProduct: await branchProductRow(db),
          priceSnapshot: 25000,
          quantity: quantity,
          notes: 'no sugar',
          selectedOptions: options,
        ),
      ],
      manualDiscountAmount: discount,
    );
  }

  group('hold', () {
    test('throws when branch is null', () async {
      final state = CartState(
        items: [
          CartItem(
            product: await productRow(db),
            branchProduct: await branchProductRow(db),
            priceSnapshot: 25000,
            quantity: 1,
          ),
        ],
      );
      expect(
        () => service.hold(state: state, label: 'Meja 1'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when cart is empty', () async {
      final state = CartState(branch: await branchRow(db));
      expect(
        () => service.hold(state: state, label: 'Meja 1'),
        throwsA(isA<StateError>()),
      );
    });

    test('writes a row scoped to the branch', () async {
      final cart = await _buildCart();
      await service.hold(state: cart, label: 'Meja 5');

      final rows = await db.select(db.heldOrders).get();
      expect(rows, hasLength(1));
      expect(rows.first.branchId, TestIds.branch);
      expect(rows.first.label, 'Meja 5');
    });

    test('replaces existing hold order with the same label', () async {
      final firstCart = await _buildCart(quantity: 1);
      final replacementCart = await _buildCart(quantity: 4, discount: 3000);

      await service.hold(state: firstCart, label: 'Meja 5');
      await service.hold(state: replacementCart, label: ' Meja   5 ');

      final rows = await db.select(db.heldOrders).get();
      expect(rows, hasLength(1));
      expect(rows.single.label, 'Meja 5');

      final restored = await service.restore(rows.single);
      expect(restored, isNotNull);
      expect(restored!.items.single.quantity, 4);
      expect(restored.manualDiscountAmount, 3000.0);
    });
  });

  group('restore roundtrip', () {
    test('items, qty, notes, and manual discount survive', () async {
      final cart = await _buildCart(quantity: 3, discount: 5000);
      await service.hold(state: cart, label: 'Meja 9');
      final row = (await db.select(db.heldOrders).get()).single;

      final restored = await service.restore(row);
      expect(restored, isNotNull);
      expect(restored!.branch?.id, TestIds.branch);
      expect(restored.items, hasLength(1));
      expect(restored.items.first.quantity, 3);
      expect(restored.items.first.notes, 'no sugar');
      expect(restored.items.first.priceSnapshot, 25000);
      expect(restored.manualDiscountAmount, 5000.0);
    });

    test('modifier options round-trip with priceDelta', () async {
      final cart = await _buildCart(
        options: const [
          CartItemOption(
            optionGroupId: 'g-milk',
            optionId: 'o-oat',
            groupName: 'Susu',
            optionName: 'Oat',
            priceDelta: 5000,
          ),
        ],
      );
      await service.hold(state: cart, label: 'Bawa Pulang');
      final row = (await db.select(db.heldOrders).get()).single;

      final restored = await service.restore(row);
      final opt = restored!.items.first.selectedOptions.single;
      expect(opt.optionId, 'o-oat');
      expect(opt.priceDelta, 5000.0);
      expect(opt.groupName, 'Susu');
    });

    test('returns null if branch row no longer exists', () async {
      final cart = await _buildCart();
      await service.hold(state: cart, label: 'Meja 3');
      final row = (await db.select(db.heldOrders).get()).single;

      // Drop the branch (cascades nuke held orders, so insert another held
      // order's worth of cleanup BEFORE deletion isn't enough — we simulate
      // the "branch gone" case by deleting the row directly with FK off).
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await (db.delete(db.branches)..where((b) => b.id.equals(TestIds.branch)))
          .go();

      final restored = await service.restore(row);
      expect(restored, isNull);
    });

    test('drops items whose product was deleted, keeps the rest', () async {
      // Insert a 2nd held order with one product that we then delete.
      final cart = await _buildCart();
      await service.hold(state: cart, label: 'Meja 7');
      final row = (await db.select(db.heldOrders).get()).single;

      await db.customStatement('PRAGMA foreign_keys = OFF');
      await (db.delete(db.products)..where((p) => p.id.equals(TestIds.product)))
          .go();

      final restored = await service.restore(row);
      // branch still resolves; product gone → items list ends up empty
      expect(restored, isNotNull);
      expect(restored!.items, isEmpty);
    });
  });

  group('discard / prune', () {
    test('discard removes a single row', () async {
      final cart = await _buildCart();
      await service.hold(state: cart, label: 'A');
      await service.hold(state: cart, label: 'B');

      final rows = await db.select(db.heldOrders).get();
      await service.discard(rows.first.id);

      final remaining = await db.select(db.heldOrders).get();
      expect(remaining, hasLength(1));
      expect(remaining.first.label, isNot(rows.first.label));
    });

    test('pruneOlderThan deletes rows older than the cutoff only', () async {
      // Direct DAO inserts so we can control createdAt.
      final old = DateTime.now().subtract(const Duration(hours: 48));
      final fresh = DateTime.now().subtract(const Duration(minutes: 30));

      Future<void> insertAt(String id, DateTime t) =>
          db.into(db.heldOrders).insert(HeldOrdersCompanion.insert(
                id: id,
                branchId: TestIds.branch,
                label: id,
                payloadJson: '{"items":[]}',
                createdAt: t,
              ));

      await insertAt('old', old);
      await insertAt('fresh', fresh);

      final pruned = await service.pruneOlderThan(const Duration(hours: 24));
      expect(pruned, 1);

      final remaining =
          (await db.select(db.heldOrders).get()).map((r) => r.id).toList();
      expect(remaining, ['fresh']);
    });
  });
}
