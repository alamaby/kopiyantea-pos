import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 25, 10, 0);

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() => db.close());

  Future<void> seedOrg(String id) async {
    await db.into(db.organizations).insert(OrganizationsCompanion.insert(
          id: id,
          name: 'Org $id',
          createdAt: now,
          updatedAt: now,
        ));
  }

  Future<void> seedNullRows() async {
    await db.into(db.branches).insert(BranchesCompanion.insert(
          id: 'b-back',
          name: 'Cabang Backfill',
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'p-back',
          name: 'Produk Backfill',
          basePrice: 10000,
          createdAt: now,
          updatedAt: now,
        ));
  }

  Future<String?> branchOrg() async {
    final row = await (db.select(db.branches)
          ..where((b) => b.id.equals('b-back')))
        .getSingle();
    return row.organizationId;
  }

  test('single org stamps NULL rows', () async {
    await seedOrg('org-solo');
    await seedNullRows();

    await db.backfillLocalOrgIds();

    expect(await branchOrg(), 'org-solo');
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals('p-back')))
        .getSingle();
    expect(product.organizationId, 'org-solo');
  });

  test('zero orgs leaves NULL untouched', () async {
    await seedNullRows();

    await db.backfillLocalOrgIds();

    expect(await branchOrg(), isNull);
  });

  test('multiple orgs leaves NULL untouched (never guesses)', () async {
    await seedOrg('org-a');
    await seedOrg('org-b');
    await seedNullRows();

    await db.backfillLocalOrgIds();

    expect(await branchOrg(), isNull);
  });
}
