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

-- Product categories
INSERT INTO categories (id, name, sort_order, color, is_active, created_at, updated_at) VALUES
  ('makanan', 'Makanan', 0, NULL, TRUE, NOW(), NOW()),
  ('minuman', 'Minuman', 1, NULL, TRUE, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  color = EXCLUDED.color,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- Products (master catalog): Makanan
INSERT INTO products (id, name, category, base_price, is_active, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000200', 'Mie Tulang', 'Makanan', 12000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000201', 'Mie Tulang Komplit', 'Makanan', 16000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000202', 'Ketan Manis Keju Coklat', 'Makanan', 7000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000203', 'Cilok Kuah Goang', 'Makanan', 6000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000204', 'Cilok Kacang', 'Makanan', 6000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000205', 'Kolak Pisang Tanduk', 'Makanan', 6000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000206', 'Rice Bowl Telur Balado', 'Makanan', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000207', 'Rice Bowl Cumi Pedas', 'Makanan', 15000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000208', 'Rice Bowl Tongkol Suwir Pedas', 'Makanan', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000209', 'Ketan Manis Keju Ori', 'Makanan', 7000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000210', 'Cumi Pedas', 'Makanan', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000211', 'Tongkol Suwir Pedas', 'Makanan', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000212', 'Nasi Putih', 'Makanan', 5000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000213', 'Telur Dadar', 'Makanan', 5000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000214', 'Nasi Goreng Kornet', 'Makanan', 16000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000215', 'Kentang Sosis', 'Makanan', 12000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000216', 'Kentang Goreng', 'Makanan', 8000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000217', 'Nasi Goreng', 'Makanan', 12000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000218', 'Gorengan Mix (Gehu Pedas, Tempe Mendoan)', 'Makanan', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000219', 'Tempe Mendoan', 'Makanan', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000220', 'Seblak', 'Makanan', 12000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000221', 'Nasi Goreng Baso Sosis', 'Makanan', 14000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000222', 'Gehu Pedas', 'Makanan', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000223', 'Mie Godog Kari', 'Makanan', 12000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000224', 'Sosis Goreng', 'Makanan', 8000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000225', 'Seblak Komplit', 'Makanan', 18000, TRUE, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  base_price = EXCLUDED.base_price,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- Products (master catalog): Minuman
INSERT INTO products (id, name, category, base_price, is_active, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000300', 'Es Teh Leci', 'Minuman', 5000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000301', 'Es Teh Lemon', 'Minuman', 5000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000302', 'Es Teh Peach', 'Minuman', 5000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000303', 'Es Kopi Susu Gula Aren', 'Minuman', 12000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000304', 'Es Kopi Susu', 'Minuman', 12000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000305', 'Es Teh Leci Small', 'Minuman', 5000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000306', 'Orange Coffee Frizz', 'Minuman', 13000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000307', 'Leci Milk', 'Minuman', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000308', 'Orange Milk', 'Minuman', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000309', 'Promo 2 Mocktail', 'Minuman', 15000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000310', 'Es Teh Manis', 'Minuman', 4000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000311', 'Melon Milk', 'Minuman', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000312', 'Melon Mist', 'Minuman', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000313', 'Strawberry Shore', 'Minuman', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000314', 'Lychee Lust', 'Minuman', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000315', 'Strawberry Milk', 'Minuman', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000316', 'Orange Oasis', 'Minuman', 10000, TRUE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000317', 'Es Kopi Hitam', 'Minuman', 7000, TRUE, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  base_price = EXCLUDED.base_price,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- Option groups
INSERT INTO option_groups (id, name, is_required, is_multi_select, sort_order, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000400', 'Bumbu Kentang Goreng', FALSE, FALSE, 0, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000401', 'Gula', FALSE, FALSE, 1, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000402', 'Espresso', FALSE, FALSE, 2, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000403', 'Upsize', FALSE, FALSE, 3, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000404', 'Pedas', FALSE, FALSE, 4, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  is_required = EXCLUDED.is_required,
  is_multi_select = EXCLUDED.is_multi_select,
  sort_order = EXCLUDED.sort_order,
  updated_at = NOW();

-- Options
INSERT INTO options (id, group_id, name, price_delta, sort_order, is_default, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000410', '00000000-0000-0000-0000-000000000400', 'Jagung Bakar', 0, 0, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000400', 'Keju', 0, 1, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000412', '00000000-0000-0000-0000-000000000400', 'Barbeque', 0, 2, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000413', '00000000-0000-0000-0000-000000000401', 'Normal', 0, 0, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000414', '00000000-0000-0000-0000-000000000401', 'Extra', 2000, 1, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000415', '00000000-0000-0000-0000-000000000401', 'Less', 0, 2, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000416', '00000000-0000-0000-0000-000000000401', 'None', 0, 3, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000417', '00000000-0000-0000-0000-000000000402', 'Single Shot', 0, 0, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000418', '00000000-0000-0000-0000-000000000402', 'Double Shot', 3000, 1, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000419', '00000000-0000-0000-0000-000000000403', '1000', 1000, 0, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000420', '00000000-0000-0000-0000-000000000403', '2000', 2000, 1, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000421', '00000000-0000-0000-0000-000000000403', '3000', 3000, 2, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000422', '00000000-0000-0000-0000-000000000403', '4000', 4000, 3, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000423', '00000000-0000-0000-0000-000000000403', '5000', 5000, 4, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000424', '00000000-0000-0000-0000-000000000403', '6000', 6000, 5, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000425', '00000000-0000-0000-0000-000000000403', '7000', 7000, 6, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000426', '00000000-0000-0000-0000-000000000403', '8000', 8000, 7, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000427', '00000000-0000-0000-0000-000000000403', '9000', 9000, 8, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000428', '00000000-0000-0000-0000-000000000404', 'Normal', 0, 0, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000429', '00000000-0000-0000-0000-000000000404', 'Extra', 2000, 1, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000430', '00000000-0000-0000-0000-000000000404', 'Less', 0, 2, FALSE, NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000431', '00000000-0000-0000-0000-000000000404', 'None', 0, 3, FALSE, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  group_id = EXCLUDED.group_id,
  name = EXCLUDED.name,
  price_delta = EXCLUDED.price_delta,
  sort_order = EXCLUDED.sort_order,
  is_default = EXCLUDED.is_default,
  updated_at = NOW();

-- Make seeded products available in every active branch.
INSERT INTO branch_products (product_id, branch_id)
SELECT p.id, b.id
  FROM products p
 CROSS JOIN branches b
 WHERE (
    p.id BETWEEN '00000000-0000-0000-0000-000000000200'
             AND '00000000-0000-0000-0000-000000000225'
    OR p.id BETWEEN '00000000-0000-0000-0000-000000000300'
                AND '00000000-0000-0000-0000-000000000317'
  )
   AND b.is_active = TRUE
ON CONFLICT (product_id, branch_id) DO NOTHING;
