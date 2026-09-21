import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/database/daos/catalog_dao.dart';
import 'package:kopiyantea_pos/core/database/daos/inventory_dao.dart';
import 'package:kopiyantea_pos/core/database/daos/outbox_dao.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';
import 'package:kopiyantea_pos/core/utils/result.dart';
import 'package:kopiyantea_pos/features/pos/cart_state.dart';
import 'package:kopiyantea_pos/features/pos/checkout_use_case.dart';
import 'package:uuid/uuid.dart';

/// Conflict-resolution and idempotency tests for the sync layer.
///
/// Scenarios:
/// 1. LWW master — server DTO overwrites stale local data.
/// 2. Transaction idempotency — duplicate insertOnConflictUpdate yields 1 row.
/// 3. Inventory movement convergence — two sales deltas both applied.
/// 4. Outbox FIFO — enqueue order matches drain order.
void main() {
  late AppDatabase db;

  final now = DateTime(2026, 9, 21, 10, 0);
  final later = now.add(const Duration(hours: 1));
  const branchId = 'b-conflict';
  const userId = 'u-conflict';
  const productId = 'p-conflict';
  const itemId = 'inv-conflict';

  setUp(() async {
    db = AppDatabase.memory();
    // Seed minimal fixture for branch + user + product + inventory item.
    await db.into(db.branches).insert(BranchesCompanion.insert(
      id: branchId,
      name: 'Cabang Conflict',
      createdAt: now,
      updatedAt: now,
    ));
    await db.into(db.appUsers).insert(AppUsersCompanion.insert(
      id: userId,
      fullName: 'Konflik User',
      globalRole: GlobalRole.owner,
      createdAt: now,
      updatedAt: now,
    ));
    await db.into(db.userBranchAccesses).insert(UserBranchAccessesCompanion.insert(
      userId: userId,
      branchId: branchId,
      roleAtBranch: const Value(BranchRole.manager),
    ));
    await db.into(db.products).insert(ProductsCompanion.insert(
      id: productId,
      name: 'Kopi Susu',
      basePrice: 18000,
      createdAt: now,
      updatedAt: now,
    ));
    await db.into(db.branchProducts).insert(BranchProductsCompanion.insert(
      productId: productId,
      branchId: branchId,
    ));
    await db.into(db.inventoryItems).insert(InventoryItemsCompanion.insert(
      id: itemId,
      branchId: branchId,
      name: 'Susu Full Cream',
      unit: StockUnit.ml,
      cachedStock: Value(1000.0),
      minStock: Value(100),
      costPerUnit: Value(2.0),
      createdAt: now,
      updatedAt: now,
    ));
    await db.into(db.productRecipes).insert(ProductRecipesCompanion.insert(
      id: 'rec-conflict-1',
      productId: productId,
      branchId: branchId,
      inventoryItemId: itemId,
      quantityRequired: 50.0,
    ));
  });

  tearDown(() => db.close());

  /// Builds a single-Latte cart from the seeded fixture (mirrors the pattern
  /// in `test/features/pos/checkout_use_case_test.dart`).
  Future<CartState> _buildCheckoutCart(
    AppDatabase db, {
    required String productId,
  }) async {
    final branch = await (db.select(db.branches)
          ..where((b) => b.id.equals(branchId)))
        .getSingle();
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals(productId)))
        .getSingle();
    final bp = await (db.select(db.branchProducts)
          ..where((bp) =>
              bp.productId.equals(productId) & bp.branchId.equals(branchId)))
        .getSingle();
    return CartState(
      branch: branch,
      items: [
        CartItem(
          product: product,
          branchProduct: bp,
          priceSnapshot: 18000,
          quantity: 1,
        ),
      ],
    );
  }

  // ── 1. LWW master: server DTO wins over stale local ────────────────────────

  test('LWW: server product update overwrites stale local data', () async {
    final catalog = CatalogDao(db);

    // Simulate local write (older timestamp).
    await catalog.upsertProduct(ProductsCompanion.insert(
      id: productId,
      name: 'Kopi Susu Local',
      basePrice: 18000,
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(minutes: 30)),
    ));

    // Simulate server pull (newer timestamp) — same as what
    // SyncRepository.pullMasterData would do via productFromJson.
    await catalog.upsertProduct(ProductsCompanion.insert(
      id: productId,
      name: 'Kopi Susu Server',
      basePrice: 22000,
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: later,
    ));

    final row = await catalog.getProductById(productId);
    expect(row, isNotNull);
    // LWW: updatedAt from server is newer → name and price should reflect
    // the server version.
    expect(row!.name, 'Kopi Susu Server');
    expect(row.basePrice, 22000);
  });

  // ── 2. Transaction idempotency ─────────────────────────────────────────────

  test('idempotency: duplicate tx insertOnConflictUpdate yields 1 row',
      () async {
    final txId = const Uuid().v7();

    final companion = TransactionsCompanion.insert(
      id: txId,
      branchId: branchId,
      cashierId: userId,
      subtotal: 18000,
      total: 18000,
      taxPercentageSnapshot: 0,
      taxLabelSnapshot: 'PB1',
      taxInclusiveSnapshot: false,
      paymentMethod: PaymentMethod.cash,
      status: TransactionStatus.completed,
      clientCreatedAt: now,
    );

    // First insert.
    await db.into(db.transactions).insertOnConflictUpdate(companion);
    // Second insert with same id — insertOnConflictUpdate is a no-op on conflict.
    await db.into(db.transactions).insertOnConflictUpdate(companion);

    final rows = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
      .get();
    expect(rows.length, 1);
  });

  // ── 3. Inventory movement convergence ─────────────────────────────────────

  test('convergence: two sale checkouts both apply to cached_stock', () async {
    final useCase = CheckoutUseCase(db: db, cashierId: userId);

    // Initial cached_stock = 1000 ml (seeded above). One Latte consumes
    // 50 ml via recipe. Two checkouts → cached_stock = 1000 − 50 − 50 = 900.
    // The movements source-of-truth (ADR-0003) plus the same arithmetic in
    // CheckoutUseCase keeps client and server converged deterministically.
    final cart = await _buildCheckoutCart(db, productId: productId);

    for (var i = 0; i < 2; i++) {
      final result = await useCase.checkout(
        cart: cart,
        paymentMethod: PaymentMethod.cash,
        paymentReceived: 50000,
      );
      expect(result, isA<Ok<CheckoutResult, CheckoutError>>());
    }

    // Both sale movements were appended (none lost).
    final movements = await InventoryDao(db).getMovementsForItem(itemId);
    expect(movements.where((m) => m.movementType == MovementType.sale),
        hasLength(2));

    // Real reconciled value (written by CheckoutUseCase, not simulated).
    final item = await (db.select(db.inventoryItems)
          ..where((i) => i.id.equals(itemId)))
        .getSingle();
    expect(item.cachedStock, 900.0);
  });

  // ── 4. Outbox FIFO ────────────────────────────────────────────────────────

  test('FIFO: enqueue order matches drain (getPendingItems) order', () async {
    final outbox = OutboxDao(db);
    final ids = List.generate(3, (i) => 'outbox-$i');

    for (int idx = 0; idx < 3; idx++) {
      final id = 'outbox-$idx';
      await outbox.enqueue(OutboxItemsCompanion.insert(
        id: id,
        entityType: OutboxEntityType.transaction,
        payload: '{"id":"$id"}',
        createdAt: now.add(Duration(seconds: idx)),
      ));
    }

    final pending = await outbox.getPendingItems();
    expect(pending.length, 3);
    expect(pending.map((e) => e.id).toList(), ids);
  });
}
