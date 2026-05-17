-- Transactions are APPEND-ONLY (master prompt §7.6, ADR-0001).
-- id is client-generated UUID v7 and also serves as the idempotency key —
-- pushes use ON CONFLICT (id) DO NOTHING.
-- Voids are compensating transactions, NOT UPDATEs.

CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  branch_id UUID NOT NULL REFERENCES branches(id),
  cashier_id UUID NOT NULL REFERENCES app_users(id),
  customer_id UUID REFERENCES customers(id),

  -- Financials
  subtotal NUMERIC NOT NULL CHECK (subtotal >= 0),
  discount_amount NUMERIC NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  tax_amount NUMERIC NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  total NUMERIC NOT NULL CHECK (total >= 0),

  -- Tax snapshot (immutable — receipts stay accurate when branch tax config changes)
  tax_percentage_snapshot NUMERIC NOT NULL
    CHECK (tax_percentage_snapshot >= 0 AND tax_percentage_snapshot <= 100),
  tax_label_snapshot TEXT NOT NULL,
  tax_inclusive_snapshot BOOLEAN NOT NULL,

  -- Payment
  payment_method TEXT NOT NULL CHECK (
    payment_method IN ('cash','qris','debit','credit','transfer','other')
  ),
  payment_received NUMERIC,
  payment_change NUMERIC,

  -- Lifecycle
  status TEXT NOT NULL CHECK (status IN ('completed','voided')),
  voided_by_transaction_id UUID REFERENCES transactions(id),
  void_reason TEXT,
  client_created_at TIMESTAMPTZ NOT NULL,
  server_received_at TIMESTAMPTZ
);

COMMENT ON COLUMN transactions.id IS
  'Client-generated UUID v7. Also serves as the idempotency key on sync push.';
COMMENT ON COLUMN transactions.tax_percentage_snapshot IS
  'Tax rate at the time of sale, copied from branches.tax_percentage. Immutable.';
COMMENT ON COLUMN transactions.voided_by_transaction_id IS
  'Self-reference: points to the compensating void transaction. NULL until voided.';
COMMENT ON COLUMN transactions.server_received_at IS
  'Set by Supabase trigger / Edge Function at first insert. Used for LWW conflict resolution on related rows.';

CREATE TABLE transaction_items (
  id UUID PRIMARY KEY,
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  name_snapshot TEXT NOT NULL,
  price_snapshot NUMERIC NOT NULL CHECK (price_snapshot >= 0),
  quantity NUMERIC NOT NULL CHECK (quantity > 0),
  subtotal NUMERIC NOT NULL CHECK (subtotal >= 0),
  notes TEXT
);

COMMENT ON COLUMN transaction_items.price_snapshot IS
  'Effective unit price (after LEVEL 2 branch standing discount, before LEVEL 1 manual discount).';
COMMENT ON COLUMN transaction_items.name_snapshot IS
  'Display name at sale time (branch_products.custom_name ?? products.name).';

-- Stamp server-received-at on first insert.
CREATE OR REPLACE FUNCTION stamp_server_received_at() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.server_received_at IS NULL THEN
    NEW.server_received_at := NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER stamp_server_received_at_on_tx
BEFORE INSERT ON transactions
FOR EACH ROW EXECUTE FUNCTION stamp_server_received_at();
