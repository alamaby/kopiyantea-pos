-- Product modifier / option system (FEAT-001).
--
-- Chain-wide design: option_groups + options are global. The
-- product_option_groups junction binds a group to specific products.
-- transaction_item_options stores immutable snapshots taken at checkout
-- so receipts and audits remain accurate when masters are later renamed.
--
-- Master data writes are owner-only. Snapshots follow the same access
-- pattern as transaction_items (append-only via parent transaction).

-- ── option_groups ─────────────────────────────────────────────────────────────

CREATE TABLE option_groups (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  is_required BOOLEAN NOT NULL DEFAULT FALSE,
  is_multi_select BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE option_groups IS
  'Modifier group (e.g. "Tingkat Gula", "Shot Espresso"). is_required forces user to pick.';

-- ── options ──────────────────────────────────────────────────────────────────

CREATE TABLE options (
  id UUID PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES option_groups(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price_delta NUMERIC NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN options.price_delta IS
  'Absolute Rupiah added to the line when this option is selected. Can be 0.';

-- ── product_option_groups ────────────────────────────────────────────────────

CREATE TABLE product_option_groups (
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  option_group_id UUID NOT NULL REFERENCES option_groups(id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, option_group_id)
);

-- ── transaction_item_options ─────────────────────────────────────────────────

CREATE TABLE transaction_item_options (
  id UUID PRIMARY KEY,
  transaction_item_id UUID NOT NULL
    REFERENCES transaction_items(id) ON DELETE CASCADE,
  option_group_name_snapshot TEXT NOT NULL,
  option_name_snapshot TEXT NOT NULL,
  price_delta_snapshot NUMERIC NOT NULL
);

COMMENT ON TABLE transaction_item_options IS
  'Append-only snapshot of selected modifier options per transaction_item. '
  'Stores names + delta as text/numeric (not FKs) so renames/deletes do not '
  'rewrite history.';

-- ── Indexes ──────────────────────────────────────────────────────────────────

CREATE INDEX idx_options_group ON options(group_id);
CREATE INDEX idx_product_option_groups_product ON product_option_groups(product_id);
CREATE INDEX idx_tx_item_options_item ON transaction_item_options(transaction_item_id);

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE option_groups            ENABLE ROW LEVEL SECURITY;
ALTER TABLE options                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_option_groups    ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_item_options ENABLE ROW LEVEL SECURITY;

-- Masters: readable to all authenticated, writable owner-only
CREATE POLICY option_groups_select_all ON option_groups
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY option_groups_write_owner ON option_groups
  FOR ALL TO authenticated
  USING (user_global_role() = 'owner')
  WITH CHECK (user_global_role() = 'owner');

CREATE POLICY options_select_all ON options
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY options_write_owner ON options
  FOR ALL TO authenticated
  USING (user_global_role() = 'owner')
  WITH CHECK (user_global_role() = 'owner');

CREATE POLICY pog_select_all ON product_option_groups
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY pog_write_owner ON product_option_groups
  FOR ALL TO authenticated
  USING (user_global_role() = 'owner')
  WITH CHECK (user_global_role() = 'owner');

-- Snapshots: same access as parent transaction_item / transactions
CREATE POLICY tx_item_options_select ON transaction_item_options
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM transaction_items ti
        JOIN transactions t ON t.id = ti.transaction_id
       WHERE ti.id = transaction_item_options.transaction_item_id
         AND user_has_branch_access(t.branch_id)
    )
  );

CREATE POLICY tx_item_options_insert ON transaction_item_options
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM transaction_items ti
        JOIN transactions t ON t.id = ti.transaction_id
       WHERE ti.id = transaction_item_options.transaction_item_id
         AND user_has_branch_access(t.branch_id)
         AND t.cashier_id = auth.uid()
    )
  );

-- NO UPDATE / DELETE policies on transaction_item_options = denied (append-only).
