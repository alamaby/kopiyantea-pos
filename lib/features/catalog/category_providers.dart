import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';

part 'category_providers.g.dart';

/// Semua kategori (termasuk yang nonaktif) — untuk layar manajemen.
@riverpod
Stream<List<CategoryRow>> allCategories(AllCategoriesRef ref) =>
    ref.watch(categoryDaoProvider).watchAll();

/// Kategori aktif saja — untuk picker di product form & filter di POS.
@riverpod
Stream<List<CategoryRow>> activeCategories(ActiveCategoriesRef ref) =>
    ref.watch(categoryDaoProvider).watchActive();

/// Lookup map `lowercase(name) → CategoryRow` untuk render warna pada tile.
@riverpod
Stream<Map<String, CategoryRow>> categoryByName(CategoryByNameRef ref) {
  return ref.watch(categoryDaoProvider).watchActive().map(
        (rows) => {for (final r in rows) r.name.toLowerCase(): r},
      );
}

/// Resolve warna kategori berdasarkan nama text di `Products.category`.
/// Mengembalikan null kalau nama tidak match atau kategori tidak punya color.
Color? resolveCategoryColor(Map<String, CategoryRow> byName, String? name) {
  if (name == null) return null;
  final row = byName[name.toLowerCase()];
  final argb = row?.color;
  return argb == null ? null : Color(argb);
}
