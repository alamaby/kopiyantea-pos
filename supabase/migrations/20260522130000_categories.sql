-- Tier 1 — kategori produk registry (sortOrder, color, isActive).
-- Mirror lokal Drift schemaVersion 12. Hubungan ke `products.category`
-- tetap via teks (bukan FK) supaya tidak breaking existing rows.
-- Non-destructive per ADR-0008.

create table if not exists public.categories (
  id text primary key,
  name text not null unique,
  sort_order integer not null default 0,
  color integer,
  is_active boolean not null default true,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

comment on table public.categories is
  'Registry kategori produk (chain-wide, single-tenant scope). Owner-managed. '
  'Hubungan ke products via text products.category (bukan FK) supaya legacy '
  'rows tetap valid; metadata sort_order + color hanya dipakai untuk render UI.';

comment on column public.categories.color is
  'Optional RGB24 0xRRGGBB untuk dot warna kategori di catalog & POS grid. NULL = '
  'tanpa warna (pakai aksen netral).';

-- RLS — pola sama dengan bank_accounts: owner-write, semua authenticated read.
alter table public.categories enable row level security;

drop policy if exists "categories read all auth" on public.categories;
create policy "categories read all auth" on public.categories
  for select to authenticated using (true);

drop policy if exists "categories owner insert" on public.categories;
create policy "categories owner insert" on public.categories
  for insert with check (user_global_role() = 'owner');

drop policy if exists "categories owner update" on public.categories;
create policy "categories owner update" on public.categories
  for update using (user_global_role() = 'owner');

drop policy if exists "categories owner delete" on public.categories;
create policy "categories owner delete" on public.categories
  for delete using (user_global_role() = 'owner');

-- Index untuk dropdown / picker yang sort by display order.
create index if not exists categories_sort_order_idx
  on public.categories (sort_order, name);
