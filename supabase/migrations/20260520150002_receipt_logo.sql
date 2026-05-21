-- FEAT-014 — receipt template config (logo position + storage bucket).
-- Non-destructive per ADR-0008.

-- ── receipt_settings.logo_position ──────────────────────────────────────────
alter table public.receipt_settings
  add column if not exists logo_position text not null default 'top'
    check (logo_position in ('top', 'bottom'));

comment on column public.receipt_settings.logo_position is
  'Where the branch logo prints on the receipt: above header (`top`) or '
  'below footer (`bottom`). Defaults to top.';

-- ── Storage bucket for receipt logos ────────────────────────────────────────
insert into storage.buckets (id, name, public)
  values ('receipt-logos', 'receipt-logos', true)
  on conflict (id) do nothing;

drop policy if exists "receipt-logos read" on storage.objects;
create policy "receipt-logos read" on storage.objects
  for select using (bucket_id = 'receipt-logos');

drop policy if exists "receipt-logos owner write" on storage.objects;
create policy "receipt-logos owner write" on storage.objects
  for insert with check (
    bucket_id = 'receipt-logos' and user_global_role() = 'owner'
  );

drop policy if exists "receipt-logos owner update" on storage.objects;
create policy "receipt-logos owner update" on storage.objects
  for update using (
    bucket_id = 'receipt-logos' and user_global_role() = 'owner'
  );

drop policy if exists "receipt-logos owner delete" on storage.objects;
create policy "receipt-logos owner delete" on storage.objects
  for delete using (
    bucket_id = 'receipt-logos' and user_global_role() = 'owner'
  );
