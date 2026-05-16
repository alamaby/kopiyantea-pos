import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/enums.dart';
import 'app_database.dart';

// ── Stable seed UUIDs ─────────────────────────────────────────────────────────
// Hardcoded so foreign keys stay consistent across reloads and the data is
// instantly recognisable as seed (all-zero prefix). NEVER reuse these in prod.

const String _kBranchTebetId = '00000000-0000-0000-0000-000000000001';
const String _kBranchSenayanId = '00000000-0000-0000-0000-000000000002';

const String _kUserOwnerId = '00000000-0000-0000-0000-000000000010';
const String _kUserManagerId = '00000000-0000-0000-0000-000000000011';
const String _kUserCashierId = '00000000-0000-0000-0000-000000000012';

const String _kProdEspresso = '00000000-0000-0000-0000-000000000100';
const String _kProdAmericano = '00000000-0000-0000-0000-000000000101';
const String _kProdCappuccino = '00000000-0000-0000-0000-000000000102';
const String _kProdLatte = '00000000-0000-0000-0000-000000000103';
const String _kProdEsKopiSusu = '00000000-0000-0000-0000-000000000104';
const String _kProdCroissant = '00000000-0000-0000-0000-000000000105';
const String _kProdRotiBakar = '00000000-0000-0000-0000-000000000106';
const String _kProdAir = '00000000-0000-0000-0000-000000000107';

const String _kInvKopiArabika = '00000000-0000-0000-0000-000000000200';
const String _kInvSusu = '00000000-0000-0000-0000-000000000201';
const String _kInvGula = '00000000-0000-0000-0000-000000000202';
const String _kInvCokelat = '00000000-0000-0000-0000-000000000203';
const String _kInvCroissantStock = '00000000-0000-0000-0000-000000000204';

const String _kCustomerBudi = '00000000-0000-0000-0000-000000000300';
const String _kCustomerSiti = '00000000-0000-0000-0000-000000000301';

// SharedPreferences key — kept in sync with [SettingsNotifier].
const String _kPrefSelectedBranchId = 'selectedBranchId';

/// Populates the local Drift database with dummy data on first run.
///
/// Idempotent: re-running is a no-op once `branches` has any row. Dev only —
/// production data flows through Supabase sync (Phase 6).
class SeedService {
  SeedService({required this.db, required this.prefs});

  final AppDatabase db;
  final SharedPreferences prefs;

  Future<void> ensureSeeded() async {
    final existing = await db.select(db.branches).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    await db.transaction(() async {
      await _seedBranches(now);
      await _seedUsers(now);
      await _seedAccess();
      await _seedProducts(now);
      await _seedBranchProducts(now);
      await _seedInventory(now);
      await _seedRecipes();
      await _seedCustomers(now);
    });

    // Auto-pick the default branch if the user hasn't chosen one yet.
    if (prefs.getString(_kPrefSelectedBranchId) == null) {
      await prefs.setString(_kPrefSelectedBranchId, _kBranchTebetId);
    }
  }

  // ── Branches ────────────────────────────────────────────────────────────────

  Future<void> _seedBranches(DateTime now) async {
    await db.into(db.branches).insert(
          BranchesCompanion.insert(
            id: _kBranchTebetId,
            name: 'Kopiyantea Tebet',
            address: const Value('Jl. Tebet Raya No. 42, Jakarta Selatan'),
            phone: const Value('+62 21 8290 0001'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.branches).insert(
          BranchesCompanion.insert(
            id: _kBranchSenayanId,
            name: 'Kopiyantea Senayan',
            address: const Value('Jl. Asia Afrika, Senayan, Jakarta Pusat'),
            phone: const Value('+62 21 5790 0002'),
            taxInclusive: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  // ── Users + access ──────────────────────────────────────────────────────────

  Future<void> _seedUsers(DateTime now) async {
    final entries = [
      ('Demo Owner', GlobalRole.owner, _kUserOwnerId),
      ('Demo Manager Tebet', GlobalRole.manager, _kUserManagerId),
      ('Demo Cashier Tebet', GlobalRole.cashier, _kUserCashierId),
    ];
    for (final (name, role, id) in entries) {
      await db.into(db.appUsers).insert(
            AppUsersCompanion.insert(
              id: id,
              fullName: name,
              globalRole: role,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _seedAccess() async {
    final accesses = [
      (_kUserManagerId, _kBranchTebetId, BranchRole.manager),
      (_kUserCashierId, _kBranchTebetId, BranchRole.cashier),
      (_kUserManagerId, _kBranchSenayanId, BranchRole.manager),
    ];
    for (final (userId, branchId, role) in accesses) {
      await db.into(db.userBranchAccesses).insert(
            UserBranchAccessesCompanion.insert(
              userId: userId,
              branchId: branchId,
              roleAtBranch: Value(role),
            ),
          );
    }
  }

  // ── Catalog ─────────────────────────────────────────────────────────────────

  Future<void> _seedProducts(DateTime now) async {
    final items = [
      (_kProdEspresso, 'Espresso', 'Kopi', 22000.0),
      (_kProdAmericano, 'Americano', 'Kopi', 25000.0),
      (_kProdCappuccino, 'Cappuccino', 'Kopi', 30000.0),
      (_kProdLatte, 'Latte', 'Kopi', 32000.0),
      (_kProdEsKopiSusu, 'Es Kopi Susu', 'Kopi Dingin', 28000.0),
      (_kProdCroissant, 'Croissant Mentega', 'Pastry', 18000.0),
      (_kProdRotiBakar, 'Roti Bakar Coklat', 'Pastry', 15000.0),
      (_kProdAir, 'Air Mineral 600ml', 'Lainnya', 8000.0),
    ];
    for (final (id, name, category, price) in items) {
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: id,
              name: name,
              category: Value(category),
              basePrice: price,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _seedBranchProducts(DateTime now) async {
    // Tebet: full menu; Latte has 10% standing discount, Es Kopi Susu has
    // a price override (Rp 30.000 → cheaper than chain average).
    final tebetMenu = [
      (_kProdEspresso, null, 0.0),
      (_kProdAmericano, null, 0.0),
      (_kProdCappuccino, null, 0.0),
      (_kProdLatte, null, 10.0),
      (_kProdEsKopiSusu, 30000.0, 0.0),
      (_kProdCroissant, null, 0.0),
      (_kProdRotiBakar, null, 0.0),
      (_kProdAir, null, 0.0),
    ];
    for (final (productId, override, discount) in tebetMenu) {
      await db.into(db.branchProducts).insert(
            BranchProductsCompanion.insert(
              productId: productId,
              branchId: _kBranchTebetId,
              priceOverride: Value(override),
              discountPercentage: Value(discount),
            ),
          );
    }

    // Senayan: smaller menu (no Roti Bakar, no Air Mineral), no overrides.
    final senayanMenu = [
      _kProdEspresso,
      _kProdAmericano,
      _kProdCappuccino,
      _kProdLatte,
      _kProdEsKopiSusu,
      _kProdCroissant,
    ];
    for (final productId in senayanMenu) {
      await db.into(db.branchProducts).insert(
            BranchProductsCompanion.insert(
              productId: productId,
              branchId: _kBranchSenayanId,
            ),
          );
    }
  }

  // ── Inventory ───────────────────────────────────────────────────────────────

  Future<void> _seedInventory(DateTime now) async {
    final items = [
      (_kInvKopiArabika, 'Kopi Arabika', StockUnit.kg, 5.0, 0.5, 250000.0),
      (_kInvSusu, 'Susu Sapi', StockUnit.liter, 10.0, 2.0, 25000.0),
      (_kInvGula, 'Gula Pasir', StockUnit.gram, 2000.0, 200.0, 18.0),
      (_kInvCokelat, 'Cokelat Bubuk', StockUnit.gram, 500.0, 100.0, 120.0),
      (_kInvCroissantStock, 'Croissant Siap', StockUnit.pcs, 20.0, 5.0, 8000.0),
    ];
    for (final (id, name, unit, stock, minStock, cost) in items) {
      await db.into(db.inventoryItems).insert(
            InventoryItemsCompanion.insert(
              id: id,
              branchId: _kBranchTebetId,
              name: name,
              unit: unit,
              cachedStock: Value(stock),
              minStock: Value(minStock),
              costPerUnit: Value(cost),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _seedRecipes() async {
    // Per-shot Espresso uses ~18g of beans (Tebet only — recipes are per branch).
    final recipes = [
      (_kProdEspresso, _kInvKopiArabika, 0.018), // kg
      (_kProdAmericano, _kInvKopiArabika, 0.018),
      (_kProdCappuccino, _kInvKopiArabika, 0.018),
      (_kProdCappuccino, _kInvSusu, 0.15), // liter
      (_kProdLatte, _kInvKopiArabika, 0.018),
      (_kProdLatte, _kInvSusu, 0.2),
      (_kProdEsKopiSusu, _kInvKopiArabika, 0.02),
      (_kProdEsKopiSusu, _kInvSusu, 0.18),
      (_kProdEsKopiSusu, _kInvGula, 15.0), // grams
      (_kProdCroissant, _kInvCroissantStock, 1.0), // pcs
    ];
    var recipeIdCounter = 1000;
    for (final (productId, invId, qty) in recipes) {
      await db.into(db.productRecipes).insert(
            ProductRecipesCompanion.insert(
              id: '00000000-0000-0000-0000-${recipeIdCounter.toString().padLeft(12, '0')}',
              productId: productId,
              branchId: _kBranchTebetId,
              inventoryItemId: invId,
              quantityRequired: qty,
            ),
          );
      recipeIdCounter++;
    }
  }

  // ── Customers ───────────────────────────────────────────────────────────────

  Future<void> _seedCustomers(DateTime now) async {
    final customers = [
      (_kCustomerBudi, 'Budi Pelanggan', '+6281200000001', 120),
      (_kCustomerSiti, 'Siti Setia', '+6281200000002', 380),
    ];
    for (final (id, name, phone, points) in customers) {
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: id,
              name: name,
              phone: Value(phone),
              loyaltyPoints: Value(points),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }
}
