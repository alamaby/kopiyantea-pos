-- Event-sourced inventory (master prompt §7.4, ADR-0003).
-- inventory_items.cached_stock is derived — never written directly by clients.
-- Reconciled by trigger from inventory_movements (see 20260518150008_inventory_trigger.sql).

CREATE TABLE inventory_items (
  id UUID PRIMARY KEY,
  branch_id UUID NOT NULL REFERENCES branches(id),
  name TEXT NOT NULL,
  unit TEXT NOT NULL CHECK (unit IN ('gram','kg','ml','liter','pcs')),
  cached_stock NUMERIC NOT NULL DEFAULT 0,
  min_stock NUMERIC NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
  cost_per_unit NUMERIC NOT NULL DEFAULT 0 CHECK (cost_per_unit >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (branch_id, name)
);

COMMENT ON COLUMN inventory_items.cached_stock IS
  'Derived: running sum of inventory_movements.delta_signed. Updated by trigger; clients write deltas not absolutes.';

CREATE TABLE inventory_movements (
  id UUID PRIMARY KEY,
  inventory_item_id UUID NOT NULL REFERENCES inventory_items(id),
  branch_id UUID NOT NULL REFERENCES branches(id),
  movement_type TEXT NOT NULL CHECK (
    movement_type IN ('purchase','sale','adjustment','waste','transfer')
  ),
  delta_signed NUMERIC NOT NULL,
  reference_id UUID,
  notes TEXT,
  created_by UUID REFERENCES app_users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN inventory_movements.delta_signed IS
  'Signed quantity change: negative for sale/waste, positive for purchase. Sums to cached_stock.';
COMMENT ON COLUMN inventory_movements.reference_id IS
  'Optional FK to source — e.g. transactions.id for a sale, purchase order id, etc.';

CREATE TABLE product_recipes (
  id UUID PRIMARY KEY,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  inventory_item_id UUID NOT NULL REFERENCES inventory_items(id),
  quantity_required NUMERIC NOT NULL CHECK (quantity_required > 0),
  UNIQUE (product_id, branch_id, inventory_item_id)
);

COMMENT ON TABLE product_recipes IS
  'Per-branch ingredient consumption per product unit sold. '
  'Drives CheckoutUseCase inventory deduction.';
