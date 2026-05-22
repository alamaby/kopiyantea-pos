import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/catalog_tables.dart';
import '../tables/category_table.dart';

part 'category_dao.g.dart';

/// CRUD + cascade-rename untuk registry kategori produk.
@DriftAccessor(tables: [Categories, Products])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<CategoryRow>> watchAll() => (select(categories)
        ..orderBy([
          (c) => OrderingTerm.asc(c.sortOrder),
          (c) => OrderingTerm.asc(c.name),
        ]))
      .watch();

  Stream<List<CategoryRow>> watchActive() => (select(categories)
        ..where((c) => c.isActive.equals(true))
        ..orderBy([
          (c) => OrderingTerm.asc(c.sortOrder),
          (c) => OrderingTerm.asc(c.name),
        ]))
      .watch();

  Future<List<CategoryRow>> getAll() => (select(categories)
        ..orderBy([
          (c) => OrderingTerm.asc(c.sortOrder),
          (c) => OrderingTerm.asc(c.name),
        ]))
      .get();

  Future<CategoryRow?> getById(String id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<CategoryRow?> getByName(String name) => (select(categories)
        ..where((c) => c.name.lower().equals(name.toLowerCase())))
      .getSingleOrNull();

  Future<void> upsert(CategoriesCompanion companion) =>
      into(categories).insertOnConflictUpdate(companion);

  Future<int> updateById(String id, CategoriesCompanion patch) =>
      (update(categories)..where((c) => c.id.equals(id))).write(patch);

  Future<int> deleteById(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  /// Berapa produk yang masih memakai nama kategori ini? Dipakai untuk
  /// memutuskan apakah delete aman atau perlu konfirmasi tambahan.
  Future<int> countProductsUsing(String categoryName) async {
    final countExpr = products.id.count();
    final row = await (selectOnly(products)
          ..addColumns([countExpr])
          ..where(products.category.equals(categoryName)))
        .getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Rename atomic + cascade ke `Products.category`. Mengembalikan daftar
  /// id produk yang ikut diubah supaya caller bisa enqueue outbox per
  /// produk (sync ke Supabase).
  Future<List<String>> renameWithCascade({
    required String id,
    required String oldName,
    required String newName,
    required DateTime now,
  }) async {
    return transaction(() async {
      await (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(newName),
          updatedAt: Value(now),
        ),
      );
      if (oldName == newName) return const <String>[];
      final affected = await (select(products)
            ..where((p) => p.category.equals(oldName)))
          .get();
      await (update(products)..where((p) => p.category.equals(oldName)))
          .write(ProductsCompanion(
        category: Value(newName),
        updatedAt: Value(now),
      ));
      return affected.map((p) => p.id).toList();
    });
  }

  /// Hapus kategori; produk yang memakainya di-set ke null (tetap muncul
  /// tapi tanpa kategori). Mengembalikan daftar id produk terpengaruh
  /// untuk enqueue outbox.
  Future<List<String>> deleteWithDetach({
    required String id,
    required String name,
    required DateTime now,
  }) async {
    return transaction(() async {
      final affected = await (select(products)
            ..where((p) => p.category.equals(name)))
          .get();
      await (update(products)..where((p) => p.category.equals(name))).write(
        ProductsCompanion(
          category: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (delete(categories)..where((c) => c.id.equals(id))).go();
      return affected.map((p) => p.id).toList();
    });
  }
}
