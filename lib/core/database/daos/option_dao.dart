import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/option_tables.dart';

part 'option_dao.g.dart';

/// Group + its options bundled for UI display.
class OptionGroupWithOptions {
  OptionGroupWithOptions({required this.group, required this.options});
  final OptionGroupRow group;
  final List<OptionRow> options;
}

@DriftAccessor(tables: [
  OptionGroups,
  MenuOptions,
  ProductOptionGroups,
  TransactionItemOptions,
])
class OptionDao extends DatabaseAccessor<AppDatabase> with _$OptionDaoMixin {
  OptionDao(super.db);

  // ── Groups ──────────────────────────────────────────────────────────────────

  Stream<List<OptionGroupRow>> watchAllGroups() => (select(optionGroups)
        ..orderBy([
          (g) => OrderingTerm.asc(g.sortOrder),
          (g) => OrderingTerm.asc(g.name),
        ]))
      .watch();

  Future<OptionGroupRow?> getGroupById(String id) =>
      (select(optionGroups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<void> upsertGroup(OptionGroupsCompanion companion) =>
      into(optionGroups).insertOnConflictUpdate(companion);

  Future<void> deleteGroup(String id) =>
      (delete(optionGroups)..where((g) => g.id.equals(id))).go();

  // ── Options ─────────────────────────────────────────────────────────────────

  Stream<List<OptionRow>> watchOptionsForGroup(String groupId) =>
      (select(menuOptions)
            ..where((o) => o.groupId.equals(groupId))
            ..orderBy([
              (o) => OrderingTerm.asc(o.sortOrder),
              (o) => OrderingTerm.asc(o.name),
            ]))
          .watch();

  Future<void> upsertOption(MenuOptionsCompanion companion) =>
      into(menuOptions).insertOnConflictUpdate(companion);

  Future<void> deleteOption(String id) =>
      (delete(menuOptions)..where((o) => o.id.equals(id))).go();

  // ── Product mapping ─────────────────────────────────────────────────────────

  /// Reactive list of groups (with their options) bound to a product, ordered
  /// by `option_groups.sort_order` then name. Includes a per-group options
  /// fetch — small N, simple over a custom watched join.
  Stream<List<OptionGroupWithOptions>> watchGroupsForProduct(
    String productId,
  ) {
    final query = select(optionGroups).join([
      innerJoin(
        productOptionGroups,
        productOptionGroups.optionGroupId.equalsExp(optionGroups.id),
      ),
    ])
      ..where(productOptionGroups.productId.equals(productId))
      ..orderBy([
        OrderingTerm.asc(optionGroups.sortOrder),
        OrderingTerm.asc(optionGroups.name),
      ]);

    return query.watch().asyncMap((rows) async {
      final result = <OptionGroupWithOptions>[];
      for (final r in rows) {
        final group = r.readTable(optionGroups);
        final opts = await (select(menuOptions)
              ..where((o) => o.groupId.equals(group.id))
              ..orderBy([
                (o) => OrderingTerm.asc(o.sortOrder),
                (o) => OrderingTerm.asc(o.name),
              ]))
            .get();
        result.add(OptionGroupWithOptions(group: group, options: opts));
      }
      return result;
    });
  }

  Future<List<OptionGroupWithOptions>> getGroupsForProduct(
    String productId,
  ) async {
    final query = select(optionGroups).join([
      innerJoin(
        productOptionGroups,
        productOptionGroups.optionGroupId.equalsExp(optionGroups.id),
      ),
    ])
      ..where(productOptionGroups.productId.equals(productId))
      ..orderBy([
        OrderingTerm.asc(optionGroups.sortOrder),
        OrderingTerm.asc(optionGroups.name),
      ]);

    final rows = await query.get();
    final result = <OptionGroupWithOptions>[];
    for (final r in rows) {
      final group = r.readTable(optionGroups);
      final opts = await (select(menuOptions)
            ..where((o) => o.groupId.equals(group.id))
            ..orderBy([
              (o) => OrderingTerm.asc(o.sortOrder),
              (o) => OrderingTerm.asc(o.name),
            ]))
          .get();
      result.add(OptionGroupWithOptions(group: group, options: opts));
    }
    return result;
  }

  Future<void> linkProductGroup({
    required String productId,
    required String optionGroupId,
  }) =>
      into(productOptionGroups).insertOnConflictUpdate(
        ProductOptionGroupsCompanion.insert(
          productId: productId,
          optionGroupId: optionGroupId,
        ),
      );

  Future<void> unlinkProductGroup({
    required String productId,
    required String optionGroupId,
  }) =>
      (delete(productOptionGroups)
            ..where((j) =>
                j.productId.equals(productId) &
                j.optionGroupId.equals(optionGroupId)))
          .go();

  // ── Transaction snapshots ──────────────────────────────────────────────────

  Future<void> insertSnapshot(
    TransactionItemOptionsCompanion companion,
  ) =>
      into(transactionItemOptions).insert(companion);

  Future<List<TransactionItemOptionRow>> getSnapshotsForItem(
    String transactionItemId,
  ) =>
      (select(transactionItemOptions)
            ..where((o) => o.transactionItemId.equals(transactionItemId)))
          .get();

  /// Bulk read for transaction detail — fetches snapshots for all items in one
  /// query then groups by transaction_item_id.
  Future<Map<String, List<TransactionItemOptionRow>>>
      getSnapshotsForItems(List<String> transactionItemIds) async {
    if (transactionItemIds.isEmpty) return const {};
    final rows = await (select(transactionItemOptions)
          ..where((o) => o.transactionItemId.isIn(transactionItemIds)))
        .get();
    final map = <String, List<TransactionItemOptionRow>>{};
    for (final r in rows) {
      map.putIfAbsent(r.transactionItemId, () => []).add(r);
    }
    return map;
  }
}
