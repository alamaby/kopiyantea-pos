-- Optional dev seed for Supabase — mirrors lib/core/database/seed_service.dart.
-- Apply AFTER creating auth.users entries with matching IDs (via Supabase
-- dashboard or `supabase auth signup`), otherwise app_users.id FK will fail.
--
-- For local dev: use the in-app seed (SeedService.ensureSeeded) instead;
-- this file exists for staging/prod parity testing.

-- Branches
INSERT INTO branches (id, name, address, phone, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Kopiyantea SGC',
   'Perumahan Subang Green City A21/15, Cibogo, Subang', '+62 81324498379', NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000002', 'Kopiyantea Kamarasan',
   'Kamarasan Residence A3/2, Bandung', '+62 81324498379', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

UPDATE branches SET tax_inclusive = TRUE
 WHERE id = '00000000-0000-0000-0000-000000000002';

-- Products (master catalog)
INSERT INTO products (id, name, category, base_price, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000100', 'Espresso',           'Kopi',         22000, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000101', 'Americano',          'Kopi',         25000, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000102', 'Cappuccino',         'Kopi',         30000, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000103', 'Latte',              'Kopi',         32000, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000104', 'Es Kopi Susu',       'Kopi Dingin',  28000, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000105', 'Croissant Mentega',  'Pastry',       18000, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000106', 'Roti Bakar Coklat',  'Pastry',       15000, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000107', 'Air Mineral 600ml',  'Lainnya',      8000,  NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Branch products for SGC (full menu, Latte gets 10% discount,
-- Es Kopi Susu gets a price override)
INSERT INTO branch_products (product_id, branch_id, price_override, discount_percentage) VALUES
  ('00000000-0000-0000-0000-000000000100', '00000000-0000-0000-0000-000000000001', NULL,   0),
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000001', NULL,   0),
  ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000001', NULL,   0),
  ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000001', NULL,   10),
  ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000001', 30000,  0),
  ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000001', NULL,   0),
  ('00000000-0000-0000-0000-000000000106', '00000000-0000-0000-0000-000000000001', NULL,   0),
  ('00000000-0000-0000-0000-000000000107', '00000000-0000-0000-0000-000000000001', NULL,   0)
ON CONFLICT (product_id, branch_id) DO NOTHING;

-- Branch products for Kamarasan (smaller menu, no overrides)
INSERT INTO branch_products (product_id, branch_id) VALUES
  ('00000000-0000-0000-0000-000000000100', '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (product_id, branch_id) DO NOTHING;
