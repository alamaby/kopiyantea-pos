-- Org parity minimal (non-destructive, ADR-0008).
-- Brings single-tenant prod (11 migrations) to the minimal multi-tenant
-- parity required by SyncRepository org-guard fallback.
-- Idempotent: all statements use IF NOT EXISTS.
-- Does NOT rewrite legacy RLS (see 20260925000003) and does NOT backfill
-- (prod empty per 2026-09-25 list_tables: 0 rows).

create extension if not exists pgcrypto;

-- ── Organizations ───────────────────────────────────────────────────────────
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  business_type text not null default 'generic'
    check (business_type in ('generic', 'fnb', 'retail', 'service', 'other')),
  address text,
  phone text,
  owner_user_id uuid references public.app_users(id) on delete set null,
  default_timezone text not null default 'Asia/Jakarta',
  status text not null default 'active'
    check (status in ('active', 'suspended', 'deleted')),
  trial_ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.app_users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'manager', 'cashier')),
  status text not null default 'active'
    check (status in ('active', 'invited', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create index if not exists organization_members_user_idx
  on public.organization_members (user_id, organization_id);

create table if not exists public.subscription_plans (
  code text primary key,
  name text not null,
  monthly_price numeric not null default 0 check (monthly_price >= 0),
  yearly_price numeric not null default 0 check (yearly_price >= 0),
  currency text not null default 'IDR',
  max_products integer check (max_products is null or max_products >= 0),
  max_monthly_transactions integer
    check (max_monthly_transactions is null or max_monthly_transactions >= 0),
  max_branches_included integer not null default 1
    check (max_branches_included >= 0),
  max_employees_per_paid_branch integer not null default 0
    check (max_employees_per_paid_branch >= 0),
  features jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.subscription_plans (
  code, name, monthly_price, yearly_price, max_products,
  max_monthly_transactions, max_branches_included,
  max_employees_per_paid_branch, features
) values
  ('free', 'Free', 0, 0, 50, 100, 1, 0,
    '{"plus_features": false}'::jsonb),
  ('plus', 'Plus', 0, 0, 500, 1000, 1, 2,
    '{"plus_features": true}'::jsonb)
on conflict (code) do update set
  name = excluded.name,
  max_products = excluded.max_products,
  max_monthly_transactions = excluded.max_monthly_transactions,
  max_branches_included = excluded.max_branches_included,
  max_employees_per_paid_branch = excluded.max_employees_per_paid_branch,
  features = excluded.features,
  updated_at = now();

create table if not exists public.organization_subscriptions (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  plan_code text not null references public.subscription_plans(code),
  status text not null check (
    status in ('trialing', 'active', 'past_due', 'canceled', 'expired')
  ),
  billing_period text check (billing_period in ('monthly', 'yearly')),
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  provider text not null default 'manual',
  provider_subscription_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.usage_counters (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  transaction_count integer not null default 0 check (transaction_count >= 0),
  product_count_snapshot integer not null default 0
    check (product_count_snapshot >= 0),
  branch_count_snapshot integer not null default 0
    check (branch_count_snapshot >= 0),
  updated_at timestamptz not null default now(),
  primary key (organization_id, period_start, period_end),
  check (period_end >= period_start)
);

create table if not exists public.company_settings (
  id text primary key default 'global',
  receipt_logo_url text,
  show_receipt_logo boolean not null default false,
  receipt_logo_position text not null default 'top'
    check (receipt_logo_position in ('top', 'bottom')),
  organization_id uuid references public.organizations(id) on delete cascade,
  updated_at timestamptz not null default now()
);

-- ── Nullable tenant columns (expand phase, no backfill: prod empty) ─────────
alter table public.branches
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.branches
  add column if not exists is_main boolean not null default false;

alter table public.products
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.categories
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.customers
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.option_groups
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.options
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.product_option_groups
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.bank_accounts
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.pending_invitations
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.customer_point_ledger
  add column if not exists organization_id uuid references public.organizations(id);

-- ── Minimal indexes ─────────────────────────────────────────────────────────
create index if not exists branches_organization_idx
  on public.branches (organization_id, is_active);

create index if not exists products_organization_idx
  on public.products (organization_id, is_active);

create index if not exists customers_organization_idx
  on public.customers (organization_id, updated_at desc);

create index if not exists bank_accounts_organization_idx
  on public.bank_accounts (organization_id, is_active, display_order);

-- ── RLS minimal (read open to authenticated; write tighten in 000003) ──────
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.organization_subscriptions enable row level security;
alter table public.usage_counters enable row level security;
alter table public.company_settings enable row level security;

-- TODO(S-07): tighten to org-aware helpers once verified on staging.
drop policy if exists organizations_read_auth on public.organizations;
create policy organizations_read_auth on public.organizations
  for select to authenticated using (true);

drop policy if exists organization_members_read_auth on public.organization_members;
create policy organization_members_read_auth on public.organization_members
  for select to authenticated using (true);

drop policy if exists subscription_plans_read on public.subscription_plans;
create policy subscription_plans_read on public.subscription_plans
  for select to authenticated using (is_active);

drop policy if exists organization_subscriptions_read_auth on public.organization_subscriptions;
create policy organization_subscriptions_read_auth on public.organization_subscriptions
  for select to authenticated using (true);

drop policy if exists usage_counters_read_auth on public.usage_counters;
create policy usage_counters_read_auth on public.usage_counters
  for select to authenticated using (true);

drop policy if exists company_settings_read_auth on public.company_settings;
create policy company_settings_read_auth on public.company_settings
  for select to authenticated using (true);

-- No backfill: prod empty per 2026-09-25 list_tables.
