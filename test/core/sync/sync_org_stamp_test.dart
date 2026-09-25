import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';
import 'package:kopiyantea_pos/core/sync/sync_dtos.dart';

void main() {
  final now = DateTime(2026, 9, 25, 10, 0);

  group('push DTOs carry organization_id', () {
    test('product roundtrip preserves org', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: 'p-org',
            name: 'Kopi Org',
            basePrice: 20000,
            organizationId: const Value('org-1'),
            createdAt: now,
            updatedAt: now,
          ));
      final row = await (db.select(db.products)
            ..where((p) => p.id.equals('p-org')))
          .getSingle();
      expect(row.toSupabaseJson()['organization_id'], 'org-1');
      final back = productFromJson({
        ...row.toSupabaseJson(),
        'base_price': 20000,
      });
      expect(back.organizationId.value, 'org-1');
    });

    test('null org passes through as null (no silent default)', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.into(db.customers).insert(CustomersCompanion.insert(
            id: 'c-null',
            name: 'Tanpa Org',
            createdAt: now,
            updatedAt: now,
          ));
      final row = await (db.select(db.customers)
            ..where((c) => c.id.equals('c-null')))
          .getSingle();
      final json = row.toSupabaseJson();
      expect(json.containsKey('organization_id'), isTrue);
      expect(json['organization_id'], isNull);
    });

    test('category + bank account carry org', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'cat-1',
            name: 'Minuman',
            organizationId: const Value('org-1'),
            createdAt: now,
            updatedAt: now,
          ));
      await db.into(db.bankAccounts).insert(BankAccountsCompanion.insert(
            id: 'bank-1',
            bankName: 'BCA',
            accountNumber: '123',
            accountHolder: 'Org',
            organizationId: const Value('org-1'),
            createdAt: now,
            updatedAt: now,
          ));
      final cat = await (db.select(db.categories)
            ..where((c) => c.id.equals('cat-1')))
          .getSingle();
      final bank = await (db.select(db.bankAccounts)
            ..where((b) => b.id.equals('bank-1')))
          .getSingle();
      expect(cat.toSupabaseJson()['organization_id'], 'org-1');
      expect(bank.toSupabaseJson()['organization_id'], 'org-1');
      expect(
        categoryFromJson(cat.toSupabaseJson()).organizationId.value,
        'org-1',
      );
      expect(
        bankAccountFromJson(bank.toSupabaseJson()).organizationId.value,
        'org-1',
      );
    });

    test('branch + option group carry org', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.into(db.branches).insert(BranchesCompanion.insert(
            id: 'b-org',
            name: 'Cabang Org',
            organizationId: const Value('org-1'),
            createdAt: now,
            updatedAt: now,
          ));
      await db.into(db.optionGroups).insert(OptionGroupsCompanion.insert(
            id: 'g-org',
            name: 'Gula',
            organizationId: const Value('org-1'),
            createdAt: now,
            updatedAt: now,
          ));
      final branch = await (db.select(db.branches)
            ..where((b) => b.id.equals('b-org')))
          .getSingle();
      final group = await (db.select(db.optionGroups)
            ..where((g) => g.id.equals('g-org')))
          .getSingle();
      expect(branch.toSupabaseJson()['organization_id'], 'org-1');
      expect(group.toSupabaseJson()['organization_id'], 'org-1');
    });

    test('transaction payload stays org-free (branch-scoped RLS)', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.into(db.branches).insert(BranchesCompanion.insert(
            id: 'b-tx',
            name: 'Cabang Tx',
            createdAt: now,
            updatedAt: now,
          ));
      await db.into(db.appUsers).insert(AppUsersCompanion.insert(
            id: 'u-tx',
            fullName: 'Kasir',
            globalRole: GlobalRole.cashier,
            createdAt: now,
            updatedAt: now,
          ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: 'tx-1',
            branchId: 'b-tx',
            cashierId: 'u-tx',
            subtotal: 10000,
            total: 11000,
            taxPercentageSnapshot: 10,
            taxLabelSnapshot: 'PB1',
            taxInclusiveSnapshot: false,
            paymentMethod: PaymentMethod.cash,
            status: TransactionStatus.completed,
            clientCreatedAt: now,
          ));
      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals('tx-1')))
          .getSingle();
      expect(tx.toSupabaseJson().containsKey('organization_id'), isFalse);
    });
  });
}
