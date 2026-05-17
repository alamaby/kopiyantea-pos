-- Performance indexes (master prompt §7.8).
-- Hot paths: branch+time scans on transactions, item+time on movements,
-- branch_id filters on branch_products, locked_until probe on app_users.

CREATE INDEX idx_transactions_branch_time
  ON transactions (branch_id, client_created_at DESC);

CREATE INDEX idx_transactions_cashier_time
  ON transactions (cashier_id, client_created_at DESC);

CREATE INDEX idx_inv_movements_item_time
  ON inventory_movements (inventory_item_id, created_at DESC);

CREATE INDEX idx_tx_items_tx
  ON transaction_items (transaction_id);

CREATE INDEX idx_branch_products_branch_available
  ON branch_products (branch_id, is_available);

-- Partial index: only rows with an active discount benefit from indexed lookups
CREATE INDEX idx_branch_products_discount_active
  ON branch_products (branch_id)
  WHERE discount_percentage > 0;

CREATE INDEX idx_products_active
  ON products (is_active);

-- Partial index: only locked users are interesting; saves space + write cost
CREATE INDEX idx_app_users_locked
  ON app_users (locked_until)
  WHERE locked_until IS NOT NULL;

-- Helper for RLS policies that check branch access for the current user
CREATE INDEX idx_user_branch_access_user
  ON user_branch_access (user_id);
