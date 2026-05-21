import 'package:drift/drift.dart';

/// ENH-001 — daily cash drawer reconciliation ("tutup kas" / Z-report).
///
/// One row per closing event. NOT used to gate transactions — purely an
/// audit log of variance between expected and counted cash so owners can
/// detect shrinkage over time.
///
/// Local-only at MVP. Supabase sync is a follow-up (would need a matching
/// table + RLS).
@DataClassName('ShiftClosingRow')
class ShiftClosings extends Table {
  TextColumn get id => text()(); // UUID v7
  TextColumn get branchId => text()();
  TextColumn get closedBy => text().nullable()(); // user id

  /// Cash put in the drawer at shift start. User-entered.
  RealColumn get openingFloat => real().withDefault(const Constant(0.0))();

  /// Sum of today's cash transactions (= sum(total) for status=completed
  /// AND payment_method=cash AND in [dayStart, closedAt]). Snapshot at
  /// close-time so historical rows stay accurate even if a later void
  /// arrives.
  RealColumn get expectedCash => real()();

  /// Physical money counted by cashier. User-entered.
  RealColumn get countedCash => real()();

  /// countedCash - (openingFloat + expectedCash). Negative = short,
  /// positive = over. Stored explicitly so reports don't need to recompute.
  RealColumn get variance => real()();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get closedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
