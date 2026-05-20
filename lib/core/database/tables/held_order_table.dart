import 'package:drift/drift.dart';

/// FEAT-009 — parked POS carts ("open bill") for dine-in flows where the
/// customer is not ready to pay yet. One row per held cart.
///
/// [payloadJson] stores a snapshot of the cart (items + customer + manual
/// discount). The cart is rebuilt at restore time by re-fetching live
/// product/branch_product rows so price changes propagate — only the
/// modifier snapshots are taken verbatim from the payload.
///
/// Local-only at MVP. Sync to Supabase is a follow-up (would need an
/// `held_orders` table + RLS + outbox push). Loss on uninstall is the
/// accepted trade-off for now.
@DataClassName('HeldOrderRow')
class HeldOrders extends Table {
  TextColumn get id => text()(); // UUID v7
  TextColumn get branchId => text()();
  TextColumn get label => text()(); // table # / customer name
  TextColumn get payloadJson => text()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
