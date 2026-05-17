-- Tenant & identity tables (master prompt §7.1)
-- Branches own tax config and brute-force defense thresholds.
-- app_users mirrors auth.users with our app-level role/lockout state.
-- user_branch_access junction grants per-branch capabilities.

-- ── branches ──────────────────────────────────────────────────────────────────

CREATE TABLE branches (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  -- Tax configuration (per-branch override of global default)
  tax_percentage NUMERIC NOT NULL DEFAULT 10
    CHECK (tax_percentage >= 0 AND tax_percentage <= 100),
  tax_label TEXT NOT NULL DEFAULT 'PB1',
  tax_inclusive BOOLEAN NOT NULL DEFAULT FALSE,

  -- Brute force defense
  failed_login_lockout_threshold INTEGER NOT NULL DEFAULT 5
    CHECK (failed_login_lockout_threshold > 0),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN branches.tax_percentage IS
  'Tax rate applied to transactions at this branch. Default 10 (PB1). Owner-configurable per branch.';
COMMENT ON COLUMN branches.tax_label IS
  'Label printed on receipt: PB1, PPN, etc.';
COMMENT ON COLUMN branches.tax_inclusive IS
  'TRUE = product prices already include tax (informational on receipt). FALSE = tax added on top of subtotal.';

-- ── app_users ─────────────────────────────────────────────────────────────────

CREATE TABLE app_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  global_role TEXT NOT NULL CHECK (global_role IN ('owner','manager','cashier')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  failed_login_count INTEGER NOT NULL DEFAULT 0
    CHECK (failed_login_count >= 0),
  locked_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN app_users.global_role IS
  'owner = chain-wide admin; manager = branch-scoped admin; cashier = POS only.';
COMMENT ON COLUMN app_users.locked_until IS
  'Set when failed_login_count >= branch.failed_login_lockout_threshold. Cleared on successful login.';

-- ── user_branch_access ────────────────────────────────────────────────────────

CREATE TABLE user_branch_access (
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  role_at_branch TEXT CHECK (role_at_branch IN ('manager','cashier')),
  PRIMARY KEY (user_id, branch_id)
);

COMMENT ON TABLE user_branch_access IS
  'Per-branch capability grant. role_at_branch overrides app_users.global_role within this branch.';
