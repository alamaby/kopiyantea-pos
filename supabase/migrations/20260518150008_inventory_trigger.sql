-- Server-side cached_stock reconciliation (ADR-0003).
--
-- inventory_items.cached_stock is derived. The client also updates it
-- locally within the same db.transaction as the movement insert (see
-- CheckoutUseCase._aggregateDeltas), so client and server converge on the
-- same value deterministically.
--
-- On sync push, only inventory_movements rows are pushed; this trigger fires
-- on the server insert and recomputes cached_stock authoritatively.

CREATE OR REPLACE FUNCTION reconcile_cached_stock() RETURNS TRIGGER AS $$
BEGIN
  UPDATE inventory_items
     SET cached_stock = cached_stock + NEW.delta_signed,
         updated_at   = NOW()
   WHERE id = NEW.inventory_item_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION reconcile_cached_stock() IS
  'Applies the signed delta to inventory_items.cached_stock atomically with the movement insert.';

CREATE TRIGGER reconcile_cached_stock_on_movement
AFTER INSERT ON inventory_movements
FOR EACH ROW EXECUTE FUNCTION reconcile_cached_stock();
