import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Enum types must be visible here so app_database.g.dart can reference them.
import '../domain/enums.dart';
import 'tables/branch_tables.dart';
import 'tables/catalog_tables.dart';
import 'tables/customer_tables.dart';
import 'tables/inventory_tables.dart';
import 'tables/option_tables.dart';
import 'tables/outbox_table.dart';
import 'tables/settings_tables.dart';
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
  ],
  // DAOs removed from annotation — instantiated as lazy getters below.
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

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
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ── Lazy DAO accessors ──────────────────────────────────────────────────────
  // Import the DAO files in the files that need them, not here.
  // These getters are the only way the rest of the app accesses DAOs.

  /// Opens the production database backed by a file on disk.
  static Future<AppDatabase> open() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kopiyantea.sqlite'));
    return AppDatabase(NativeDatabase.createInBackground(file));
  }

  /// In-memory database for unit/widget tests.
  static AppDatabase memory() => AppDatabase(NativeDatabase.memory());
}
