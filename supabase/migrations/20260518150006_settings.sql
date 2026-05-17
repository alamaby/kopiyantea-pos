-- Per-branch receipt config (master prompt §7.7).
-- One row per branch — header/footer text, logo, paper width, locale.

CREATE TABLE receipt_settings (
  id UUID PRIMARY KEY,
  branch_id UUID NOT NULL UNIQUE REFERENCES branches(id),
  header_text TEXT,
  footer_text TEXT,
  logo_url TEXT,
  paper_width_mm INTEGER NOT NULL DEFAULT 58 CHECK (paper_width_mm IN (58, 80)),
  show_logo BOOLEAN NOT NULL DEFAULT FALSE,
  locale TEXT NOT NULL DEFAULT 'id_ID',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN receipt_settings.paper_width_mm IS
  'Thermal printer paper width. 58mm = most mobile printers; 80mm = full-size station printers.';
