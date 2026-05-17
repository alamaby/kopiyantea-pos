-- Customer roster (master prompt §7.5). Phone is unique when present.

CREATE TABLE customers (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT UNIQUE,
  email TEXT,
  loyalty_points INTEGER NOT NULL DEFAULT 0 CHECK (loyalty_points >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN customers.loyalty_points IS
  'Earned/spent via transactions. Update flow (earn rules) lives in app logic.';
