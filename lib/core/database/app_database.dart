import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Enum types must be visible here so app_database.g.dart can reference them.
import '../domain/enums.dart';
import 'tables/bank_account_table.dart';
import 'tables/branch_tables.dart';
import 'tables/catalog_tables.dart';
import 'tables/category_table.dart';
import 'tables/customer_tables.dart';
import 'tables/held_order_table.dart';
import 'tables/inventory_tables.dart';
import 'tables/option_tables.dart';
import 'tables/outbox_table.dart';
import 'tables/settings_tables.dart';
import 'tables/shift_closing_table.dart';
import 'tables/transaction_tables.dart';

// DAOs are NOT imported here — that would create a circular dependency
// (DAO files import AppDatabase; if AppDatabase imports DAOs, Dart can't
// resolve types). Instead, DAOs are exposed as lazy getters below, and
// each DAO file imports this file unidirectionally.
part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Branches,
    AppUsers,
    UserBranchAccesses,
    Products,
    BranchProducts,
    InventoryItems,
    InventoryMovements,
    ProductRecipes,
    Customers,
    Transactions,
    TransactionItems,
    ReceiptSettings,
    OutboxItems,
    // FEAT-001 — modifier system (added at schemaVersion 2)
    OptionGroups,
    MenuOptions,
    ProductOptionGroups,
    TransactionItemOptions,
    // FEAT-006 — pending invitations table (added at schemaVersion 3)
    PendingInvitations,
    // FEAT-009 — held orders / open bill (added at schemaVersion 4)
    HeldOrders,
    // ENH-001 — daily cash reconciliation log (added at schemaVersion 5)
    ShiftClosings,
    // FEAT-015 — global bank accounts for transfer payment (schemaVersion 9)
    BankAccounts,
    // Tier 1 — kategori produk registry (schemaVersion 12)
    Categories,
  ],
  // DAOs removed from annotation — instantiated as lazy getters below.
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // ADR-0008 — non-destructive migrations only.
          if (from < 2) {
            // FEAT-001 modifier system tables.
            await m.createTable(optionGroups);
            await m.createTable(menuOptions);
            await m.createTable(productOptionGroups);
            await m.createTable(transactionItemOptions);
          }
          if (from < 3) {
            // FEAT-006 — add `email` to app_users + pending_invitations table.
            await m.addColumn(appUsers, appUsers.email);
            await m.createTable(pendingInvitations);
          }
          if (from < 4) {
            // FEAT-009 — local-only held orders.
            await m.createTable(heldOrders);
          }
          if (from < 5) {
            // ENH-001 — local-only shift closings.
            await m.createTable(shiftClosings);
          }
          if (from < 6) {
            // FEAT-013 — add qris_image_url column to branches.
            await m.addColumn(branches, branches.qrisImageUrl);
          }
          if (from < 7) {
            // FEAT-014 — receipt template config (logo position field).
            await m.addColumn(
              receiptSettings,
              receiptSettings.logoPosition,
            );
          }
          if (from < 8) {
            // FEAT-014b — opt-in cashier name on receipt.
            await m.addColumn(receiptSettings, receiptSettings.showCashierName);
          }
          if (from < 9) {
            // FEAT-015 — global bank accounts + transaction FK + snapshot.
            await m.createTable(bankAccounts);
            await m.addColumn(transactions, transactions.bankAccountId);
            await m.addColumn(transactions, transactions.bankAccountSnapshot);
          }
          if (from < 10) {
            // ENH-004 — opt-in printing static QRIS on receipt.
            await m.addColumn(
                receiptSettings, receiptSettings.printQrisOnReceipt);
          }
          if (from < 11) {
            // Cashier name snapshot — make struk lama tahan terhadap
            // perubahan/penghapusan user.
            await m.addColumn(transactions, transactions.cashierNameSnapshot);
          }
          if (from < 12) {
            // Tier 1 — kategori registry + seed dari distinct
            // Products.category yang sudah ada.
            await m.createTable(categories);
            await _seedCategoriesFromExistingProducts();
          }
          if (from < 13) {
            // Receipt visibility toggles for customer and branch name.
            await m.addColumn(
                receiptSettings, receiptSettings.showCustomerName);
            await m.addColumn(receiptSettings, receiptSettings.showBranchName);
          }
          if (from < 14) {
            // Human-readable transaction number for receipts and owner lookup.
            await m.addColumn(transactions, transactions.transactionNumber);
          }
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await _sanitizeCategoryColors();
        },
      );

  // ── Lazy DAO accessors ──────────────────────────────────────────────────────
  // Import the DAO files in the files that need them, not here.
  // These getters are the only way the rest of the app accesses DAOs.

  /// Opens the production database backed by a file on disk.
  static Future<AppDatabase> open() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kopiyantea.sqlite'));
    return AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA busy_timeout = 5000;');
          db.execute('PRAGMA journal_mode = WAL;');
        },
      ),
    );
  }

  /// In-memory database for unit/widget tests.
  static AppDatabase memory() => AppDatabase(NativeDatabase.memory());

  /// Tier 1 — bootstrap `categories` dari nilai unik `products.category`
  /// yang sudah ada. Dipanggil dari migrasi v11→v12. Memakai raw
  /// `customStatement` supaya tidak butuh DAO baru di sini (DAO belum
  /// di-import; menghindari circular import).
  Future<void> _seedCategoriesFromExistingProducts() async {
    final rows = await customSelect(
      'SELECT DISTINCT category FROM products '
      "WHERE category IS NOT NULL AND TRIM(category) <> '' "
      'ORDER BY category COLLATE NOCASE',
    ).get();
    final now = DateTime.now().toIso8601String();
    var order = 0;
    for (final r in rows) {
      final name = r.read<String>('category').trim();
      if (name.isEmpty) continue;
      // UUID-ish id from name + order — cukup unik untuk seed migrasi.
      // Avoid uuid pkg di sini (zona migrasi, tetap ringan).
      final id =
          'seed-${DateTime.now().microsecondsSinceEpoch}-$order-${name.hashCode}';
      await customStatement(
        'INSERT OR IGNORE INTO categories '
        '(id, name, sort_order, color, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, NULL, 1, ?, ?)',
        [id, name, order, now, now],
      );
      order++;
    }
  }

  /// Normalisasi data lama/korup sebelum Drift membaca `categories.color`.
  /// SQLite bisa menyimpan teks pada kolom integer; saat Drift membacanya,
  /// teks hex seperti `#EF4444` akan diparse sebagai radix-10 dan gagal.
  Future<void> _sanitizeCategoryColors() async {
    await customStatement(
      'UPDATE categories SET color = NULL '
      "WHERE color IS NOT NULL AND typeof(color) = 'text' "
      "AND TRIM(color) NOT GLOB '[0-9]*'",
    );
    await customStatement(
      'UPDATE categories SET color = CAST(color AS INTEGER) & 16777215 '
      'WHERE color IS NOT NULL',
    );
  }
}
