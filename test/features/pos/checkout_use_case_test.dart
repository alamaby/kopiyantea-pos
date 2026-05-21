import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';
import 'package:kopiyantea_pos/features/pos/cart_state.dart';
import 'package:kopiyantea_pos/features/pos/checkout_use_case.dart';
import 'package:kopiyantea_pos/core/utils/result.dart';

/// ENH-015 — happy-path integration test for [CheckoutUseCase].
///
/// Uses an in-memory Drift DB seeded with minimal fixtures so the use case
/// runs the same atomic transaction it would in production: tx header +
/// items + inventory movements + cached_stock reconciliation + outbox row.
///
/// Each test creates its own DB and tears it down — no shared state.
void main() {
  late AppDatabase db;
  late CheckoutUseCase useCase;
  const branchId = 'b1';
  const cashierId = 'u1';
  const productId = 'p1';
  const inventoryItemId = 'inv-milk';
  const recipeId = 'rec-1';

  setUp(() async {
    db = AppDatabase.memory();
    useCase = CheckoutUseCase(db: db, cashierId: cashierId);
    await _seed(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('happy path: writes tx + items + movements + outbox atomically',
      () async {
    final cart = await _buildCart(db);

    final result = await useCase.checkout(
      cart: cart,
      paymentMethod: PaymentMethod.cash,
      paymentReceived: 50000,
    );

    expect(result, isA<Ok<CheckoutResult, CheckoutError>>());
    final txId = (result as Ok<CheckoutResult, CheckoutError>).value.transactionId;

    // Header
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingleOrNull();
    expect(tx, isNotNull);
    expect(tx!.branchId, branchId);
    expect(tx.status, TransactionStatus.completed);
    expect(tx.cashierId, cashierId);
    expect(tx.paymentMethod, PaymentMethod.cash);
    // Single Latte @ 25000, branch tax 10% exclusive → 27500
    expect(tx.subtotal, 25000);
    expect(tx.taxAmount, 2500);
    expect(tx.total, 27500);

    // Items
    final items = await (db.select(db.transactionItems)
          ..where((i) => i.transactionId.equals(txId)))
        .get();
    expect(items, hasLength(1));
    expect(items.first.productId, productId);
    expect(items.first.quantity, 1.0);

    // Inventory movements
    final movs = await (db.select(db.inventoryMovements)
          ..where((m) => m.referenceId.equals(txId)))
        .get();
    expect(movs, hasLength(1));
    expect(movs.first.inventoryItemId, inventoryItemId);
    expect(movs.first.movementType, MovementType.sale);
    expect(movs.first.deltaSigned, -50.0); // recipe: 50ml per Latte

    // Cached stock reconciled locally (started at 1000)
    final invItem = await (db.select(db.inventoryItems)
          ..where((i) => i.id.equals(inventoryItemId)))
        .getSingle();
    expect(invItem.cachedStock, 950.0);

    // Outbox row enqueued
    final outboxRows = await db.select(db.outboxItems).get();
    expect(outboxRows, hasLength(1));
    expect(outboxRows.first.entityType, OutboxEntityType.transaction);
    expect(outboxRows.first.status, OutboxStatus.pending);
  });

  test('empty cart returns emptyCart error and writes nothing', () async {
    final emptyCart = CartState(branch: await _branchRow(db));
    final result = await useCase.checkout(
      cart: emptyCart,
      paymentMethod: PaymentMethod.cash,
      paymentReceived: 0,
    );
    expect(result, isA<Err<CheckoutResult, CheckoutError>>());
    expect((result as Err).error, CheckoutError.emptyCart);

    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.outboxItems).get(), isEmpty);
  });

  test('insufficient cash returns invalidPayment and writes nothing',
      () async {
    final cart = await _buildCart(db);
    final result = await useCase.checkout(
      cart: cart,
      paymentMethod: PaymentMethod.cash,
      paymentReceived: 10000, // less than 27500 total
    );
    expect((result as Err).error, CheckoutError.invalidPayment);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.inventoryMovements).get(), isEmpty);
    expect(await db.select(db.outboxItems).get(), isEmpty);

    // Cached stock unchanged
    final invItem = await (db.select(db.inventoryItems)
          ..where((i) => i.id.equals(inventoryItemId)))
        .getSingle();
    expect(invItem.cachedStock, 1000.0);
  });

  test('non-cash payment does not require paymentReceived', () async {
    final cart = await _buildCart(db);
    final result = await useCase.checkout(
      cart: cart,
      paymentMethod: PaymentMethod.qris,
    );
    expect(result, isA<Ok<CheckoutResult, CheckoutError>>());
    final tx = (await db.select(db.transactions).get()).single;
    expect(tx.paymentMethod, PaymentMethod.qris);
    expect(tx.paymentReceived, isNull);
    expect(tx.paymentChange, isNull);
  });

  test('aggregates deltas when same inventory item appears across lines',
      () async {
    final cart = await _buildCart(db, quantity: 3);
    final result = await useCase.checkout(
      cart: cart,
      paymentMethod: PaymentMethod.cash,
      paymentReceived: 200000,
    );
    expect(result, isA<Ok<CheckoutResult, CheckoutError>>());

    final invItem = await (db.select(db.inventoryItems)
          ..where((i) => i.id.equals(inventoryItemId)))
        .getSingle();
    // 3 × 50ml = 150 deducted from 1000
    expect(invItem.cachedStock, 850.0);
  });
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

Future<void> _seed(AppDatabase db) async {
  final now = DateTime(2026, 5, 20, 10);
  await db.into(db.branches).insert(BranchesCompanion.insert(
        id: 'b1',
        name: 'Cabang Tes',
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.appUsers).insert(AppUsersCompanion.insert(
        id: 'u1',
        fullName: 'Kasir Tes',
        globalRole: GlobalRole.cashier,
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.products).insert(ProductsCompanion.insert(
        id: 'p1',
        name: 'Latte',
        basePrice: 25000,
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.branchProducts).insert(BranchProductsCompanion.insert(
        productId: 'p1',
        branchId: 'b1',
      ));
  await db.into(db.inventoryItems).insert(InventoryItemsCompanion.insert(
        id: 'inv-milk',
        branchId: 'b1',
        name: 'Susu',
        unit: StockUnit.ml,
        cachedStock: const Value(1000.0),
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.productRecipes).insert(ProductRecipesCompanion.insert(
        id: 'rec-1',
        productId: 'p1',
        branchId: 'b1',
        inventoryItemId: 'inv-milk',
        quantityRequired: 50.0,
      ));
}

Future<BranchRow> _branchRow(AppDatabase db) =>
    (db.select(db.branches)..where((b) => b.id.equals('b1'))).getSingle();

Future<CartState> _buildCart(AppDatabase db, {int quantity = 1}) async {
  final branch = await _branchRow(db);
  final product = await (db.select(db.products)
        ..where((p) => p.id.equals('p1')))
      .getSingle();
  final bp = await (db.select(db.branchProducts)
        ..where((bp) => bp.productId.equals('p1') & bp.branchId.equals('b1')))
      .getSingle();
  return CartState(
    branch: branch,
    items: [
      CartItem(
        product: product,
        branchProduct: bp,
        priceSnapshot: 25000,
        quantity: quantity,
      ),
    ],
  );
}
