-- FEAT-012 product photos + FEAT-013 static QRIS image upload.
-- Non-destructive per ADR-0008.

-- ── Branch.qris_image_url column ────────────────────────────────────────────
alter table public.branches
  add column if not exists qris_image_url text;

comment on column public.branches.qris_image_url is
  'Public URL of the branch static QRIS image in the qris-images bucket. '
  'Null = no QR uploaded; UI hides QRIS payment shortcut.';

-- ── Storage buckets ─────────────────────────────────────────────────────────
-- Both public-read for fast CDN access. Writes are gated by owner role
-- below via storage RLS. Use ON CONFLICT to keep migration idempotent.

insert into storage.buckets (id, name, public)
  values ('product-images', 'product-images', true)
  on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
  values ('qris-images', 'qris-images', true)
  on conflict (id) do nothing;

-- ── RLS policies on storage.objects ─────────────────────────────────────────
-- Read: anyone (bucket is public, but a permissive SELECT policy is still
-- required for the storage API to serve public URLs).
-- Write/Update/Delete: authenticated user with global_role = owner.
-- Reuse the existing user_global_role() helper from migration 009.

drop policy if exists "product-images read" on storage.objects;
create policy "product-images read" on storage.objects
  for select using (bucket_id = 'product-images');

drop policy if exists "product-images owner write" on storage.objects;
create policy "product-images owner write" on storage.objects
  for insert with check (
    bucket_id = 'product-images' and user_global_role() = 'owner'
  );

drop policy if exists "product-images owner update" on storage.objects;
create policy "product-images owner update" on storage.objects
  for update using (
    bucket_id = 'product-images' and user_global_role() = 'owner'
  );

drop policy if exists "product-images owner delete" on storage.objects;
create policy "product-images owner delete" on storage.objects
  for delete using (
    bucket_id = 'product-images' and user_global_role() = 'owner'
  );

drop policy if exists "qris-images read" on storage.objects;
create policy "qris-images read" on storage.objects
  for select using (bucket_id = 'qris-images');

drop policy if exists "qris-images owner write" on storage.objects;
create policy "qris-images owner write" on storage.objects
  for insert with check (
    bucket_id = 'qris-images' and user_global_role() = 'owner'
  );

drop policy if exists "qris-images owner update" on storage.objects;
create policy "qris-images owner update" on storage.objects
  for update using (
    bucket_id = 'qris-images' and user_global_role() = 'owner'
  );

drop policy if exists "qris-images owner delete" on storage.objects;
create policy "qris-images owner delete" on storage.objects
  for delete using (
    bucket_id = 'qris-images' and user_global_role() = 'owner'
  );
