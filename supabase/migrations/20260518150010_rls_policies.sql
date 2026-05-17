-- Row Level Security policy matrix (ADR-0007, master prompt §8).
--
-- Deny-by-default: every table starts with ENABLE ROW LEVEL SECURITY.
-- Policies are split per operation (SELECT/INSERT/UPDATE/DELETE) where the
-- access rule differs. transactions + transaction_items are intentionally
-- missing UPDATE/DELETE policies — append-only, voids are compensating rows.

-- ── Enable RLS on every table ─────────────────────────────────────────────────

ALTER TABLE branches             ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_branch_access   ENABLE ROW LEVEL SECURITY;
ALTER TABLE products             ENABLE ROW LEVEL SECURITY;
ALTER TABLE branch_products      ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements  ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_recipes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers            ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_settings     ENABLE ROW LEVEL SECURITY;

-- ── branches ──────────────────────────────────────────────────────────────────

CREATE POLICY branches_select ON branches
  FOR SELECT TO authenticated
  USING (user_global_role() = 'owner' OR user_has_branch_access(id));

CREATE POLICY branches_write ON branches
  FOR ALL TO authenticated
  USING (user_global_role() = 'owner')
  WITH CHECK (user_global_role() = 'owner');

-- ── app_users ─────────────────────────────────────────────────────────────────

CREATE POLICY app_users_select ON app_users
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR user_global_role() = 'owner'
    OR EXISTS (
      SELECT 1 FROM user_branch_access uba1
      JOIN user_branch_access uba2 ON uba1.branch_id = uba2.branch_id
      WHERE uba1.user_id = auth.uid()
        AND uba2.user_id = app_users.id
    )
  );

CREATE POLICY app_users_insert ON app_users
  FOR INSERT TO authenticated
  WITH CHECK (user_global_role() = 'owner');

CREATE POLICY app_users_update_self ON app_users
  FOR UPDATE TO authenticated
  USING (id = auth.uid() OR user_global_role() = 'owner')
  WITH CHECK (id = auth.uid() OR user_global_role() = 'owner');

CREATE POLICY app_users_delete_owner ON app_users
  FOR DELETE TO authenticated
  USING (user_global_role() = 'owner');

-- ── user_branch_access ────────────────────────────────────────────────────────

CREATE POLICY uba_select ON user_branch_access
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR user_global_role() = 'owner');

CREATE POLICY uba_write ON user_branch_access
  FOR ALL TO authenticated
  USING (user_global_role() = 'owner')
  WITH CHECK (user_global_role() = 'owner');

-- ── products (master catalog: owner-only writable, readable to all) ──────────

CREATE POLICY products_select_all ON products
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY products_write_owner ON products
  FOR ALL TO authenticated
  USING (user_global_role() = 'owner')
  WITH CHECK (user_global_role() = 'owner');

-- ── branch_products (owner OR manager-of-branch) ─────────────────────────────

CREATE POLICY branch_products_select ON branch_products
  FOR SELECT TO authenticated
  USING (user_has_branch_access(branch_id));

CREATE POLICY branch_products_write ON branch_products
  FOR ALL TO authenticated
  USING (
    user_global_role() = 'owner'
    OR (user_has_branch_access(branch_id) AND user_global_role() = 'manager')
  )
  WITH CHECK (
    user_global_role() = 'owner'
    OR (user_has_branch_access(branch_id) AND user_global_role() = 'manager')
  );

-- ── inventory_items ──────────────────────────────────────────────────────────

CREATE POLICY inventory_items_select ON inventory_items
  FOR SELECT TO authenticated
  USING (user_has_branch_access(branch_id));

CREATE POLICY inventory_items_write ON inventory_items
  FOR ALL TO authenticated
  USING (
    user_global_role() = 'owner'
    OR (user_has_branch_access(branch_id) AND user_global_role() = 'manager')
  )
  WITH CHECK (
    user_global_role() = 'owner'
    OR (user_has_branch_access(branch_id) AND user_global_role() = 'manager')
  );

-- ── inventory_movements (append-only — read for branch members; insert with
--                          created_by = auth.uid() ── any branch member can write) ──

CREATE POLICY inv_movements_select ON inventory_movements
  FOR SELECT TO authenticated
  USING (user_has_branch_access(branch_id));

CREATE POLICY inv_movements_insert ON inventory_movements
  FOR INSERT TO authenticated
  WITH CHECK (
    user_has_branch_access(branch_id)
    AND (created_by IS NULL OR created_by = auth.uid())
  );

-- ── product_recipes (manager/owner writable, accessor readable) ──────────────

CREATE POLICY product_recipes_select ON product_recipes
  FOR SELECT TO authenticated
  USING (user_has_branch_access(branch_id));

CREATE POLICY product_recipes_write ON product_recipes
  FOR ALL TO authenticated
  USING (
    user_global_role() = 'owner'
    OR (user_has_branch_access(branch_id) AND user_global_role() = 'manager')
  )
  WITH CHECK (
    user_global_role() = 'owner'
    OR (user_has_branch_access(branch_id) AND user_global_role() = 'manager')
  );

-- ── customers (chain-wide visibility) ────────────────────────────────────────

CREATE POLICY customers_select_all ON customers
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY customers_insert ON customers
  FOR INSERT TO authenticated
  WITH CHECK (TRUE);

CREATE POLICY customers_update ON customers
  FOR UPDATE TO authenticated
  USING (TRUE)
  WITH CHECK (TRUE);

CREATE POLICY customers_delete_owner ON customers
  FOR DELETE TO authenticated
  USING (user_global_role() = 'owner');

-- ── transactions (APPEND-ONLY — no UPDATE/DELETE policies) ───────────────────

CREATE POLICY transactions_select ON transactions
  FOR SELECT TO authenticated
  USING (user_has_branch_access(branch_id));

CREATE POLICY transactions_insert ON transactions
  FOR INSERT TO authenticated
  WITH CHECK (
    user_has_branch_access(branch_id)
    AND cashier_id = auth.uid()
  );

-- NO UPDATE policy = denied
-- NO DELETE policy = denied

-- ── transaction_items (same access as parent transaction) ────────────────────

CREATE POLICY tx_items_select ON transaction_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM transactions t
       WHERE t.id = transaction_items.transaction_id
         AND user_has_branch_access(t.branch_id)
    )
  );

CREATE POLICY tx_items_insert ON transaction_items
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM transactions t
       WHERE t.id = transaction_items.transaction_id
         AND user_has_branch_access(t.branch_id)
         AND t.cashier_id = auth.uid()
    )
  );

-- ── receipt_settings ─────────────────────────────────────────────────────────

CREATE POLICY receipt_settings_select ON receipt_settings
  FOR SELECT TO authenticated
  USING (user_has_branch_access(branch_id));

CREATE POLICY receipt_settings_write ON receipt_settings
  FOR ALL TO authenticated
  USING (
    user_global_role() = 'owner'
    OR (user_has_branch_access(branch_id) AND user_global_role() = 'manager')
  )
  WITH CHECK (
    user_global_role() = 'owner'
    OR (user_has_branch_access(branch_id) AND user_global_role() = 'manager')
  );
