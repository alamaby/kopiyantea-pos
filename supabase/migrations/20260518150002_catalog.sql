-- Global master catalog + per-branch junction (master prompt §7.2, ADR-0006).
-- Owner edits products once; branches override via branch_products.

CREATE TABLE products (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT,
  base_price NUMERIC NOT NULL CHECK (base_price >= 0),
  sku TEXT UNIQUE,
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE products IS
  'Master catalog — owner-only writable. is_active=false soft-deletes (ADR-0008).';
COMMENT ON COLUMN products.sku IS
  'Stock-keeping unit code. Optional but unique when set.';

CREATE TABLE branch_products (
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  price_override NUMERIC CHECK (price_override IS NULL OR price_override >= 0),
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  custom_name TEXT,
  discount_percentage NUMERIC NOT NULL DEFAULT 0
    CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
  discount_valid_until TIMESTAMPTZ,
  PRIMARY KEY (product_id, branch_id)
);

COMMENT ON TABLE branch_products IS
  'Per-branch override of price/discount/availability. Resolution order: '
  'price_override ?? base_price, then × (1 - discount/100) when discount valid.';
COMMENT ON COLUMN branch_products.price_override IS
  'When set, replaces products.base_price for this branch. Discount applies to this value (ADR-0011).';
COMMENT ON COLUMN branch_products.discount_valid_until IS
  'NULL = no expiry. Discount is skipped when in the past.';
