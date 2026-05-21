-- FEAT-015 — global bank accounts for transfer payment + transaction
-- bank_account_id FK + snapshot. Non-destructive per ADR-0008.

-- ── bank_accounts table ─────────────────────────────────────────────────────
create table if not exists public.bank_accounts (
  id text primary key,
  bank_name text not null,
  account_number text not null,
  account_holder text not null,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

comment on table public.bank_accounts is
  'Global (chain-wide, single-tenant scope) bank accounts available for '
  'transfer-method payments. Owner-managed. Cashier picks one at checkout '
  'and the transaction stores both the FK + an immutable snapshot.';

-- RLS — owner-write, all authenticated-read (kasir butuh baca buat picker).
alter table public.bank_accounts enable row level security;

drop policy if exists "bank_accounts read all auth" on public.bank_accounts;
create policy "bank_accounts read all auth" on public.bank_accounts
  for select to authenticated using (true);

drop policy if exists "bank_accounts owner insert" on public.bank_accounts;
create policy "bank_accounts owner insert" on public.bank_accounts
  for insert with check (user_global_role() = 'owner');

drop policy if exists "bank_accounts owner update" on public.bank_accounts;
create policy "bank_accounts owner update" on public.bank_accounts
  for update using (user_global_role() = 'owner');

drop policy if exists "bank_accounts owner delete" on public.bank_accounts;
create policy "bank_accounts owner delete" on public.bank_accounts
  for delete using (user_global_role() = 'owner');

-- ── transactions.bank_account_id + snapshot ─────────────────────────────────
alter table public.transactions
  add column if not exists bank_account_id text references public.bank_accounts(id)
    on delete set null;

alter table public.transactions
  add column if not exists bank_account_snapshot text;

comment on column public.transactions.bank_account_id is
  'FK to the rekening chosen at checkout for transfer payments. ON DELETE '
  'SET NULL so removing a rekening preserves historical transactions; the '
  'snapshot column keeps the display string.';

comment on column public.transactions.bank_account_snapshot is
  'Immutable display string ("BCA 1234567890 - John Doe") set when the '
  'transaction was created. Survives owner editing/deleting the rekening.';

-- Index for report filtering by rekening.
create index if not exists transactions_bank_account_id_idx
  on public.transactions (bank_account_id)
  where bank_account_id is not null;
