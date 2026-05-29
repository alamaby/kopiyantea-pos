-- Append-only loyalty point ledger. customers.loyalty_points remains a cached
-- balance for fast UI reads; this ledger is the auditable source of changes.

create table if not exists public.customer_point_ledger (
  id uuid primary key,
  customer_id uuid not null references public.customers(id),
  transaction_id uuid references public.transactions(id),
  points_delta integer not null check (points_delta <> 0),
  reason text not null check (
    reason in ('earn', 'void_reversal', 'manual_adjustment', 'redeem')
  ),
  created_at timestamptz not null
);

create unique index if not exists customer_point_ledger_tx_reason_uq
  on public.customer_point_ledger (transaction_id, reason)
  where transaction_id is not null;

create index if not exists customer_point_ledger_customer_time_idx
  on public.customer_point_ledger (customer_id, created_at desc);

comment on table public.customer_point_ledger is
  'Append-only audit ledger for customer loyalty point changes.';
comment on column public.customer_point_ledger.points_delta is
  'Positive for earned/adjustment points, negative for void reversal or redeem.';

alter table public.customer_point_ledger enable row level security;

create policy customer_point_ledger_select_all
  on public.customer_point_ledger
  for select to authenticated
  using (true);

create policy customer_point_ledger_insert
  on public.customer_point_ledger
  for insert to authenticated
  with check (true);

create policy customer_point_ledger_delete_owner
  on public.customer_point_ledger
  for delete to authenticated
  using (user_global_role() = 'owner');
