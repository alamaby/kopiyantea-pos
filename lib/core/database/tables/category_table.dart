import 'package:drift/drift.dart';

/// Tier 1 kategori — registry lokal nama kategori produk dengan metadata
/// tampilan. Hubungan ke `Products` tetap via nilai text `Products.category`
/// (bukan FK) supaya jalur sinkronisasi yang sudah ada tidak perlu berubah:
/// Supabase masih menerima `products.category` sebagai text. Rename pada
/// tabel ini di-cascade ke `Products.category` di sisi klien.
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()(); // UUID v7
  TextColumn get name => text()(); // unique (case-insensitive di DAO)
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  /// ARGB32 (nullable). Null = pakai aksen netral.
  IntColumn get color => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {name},
      ];
}
