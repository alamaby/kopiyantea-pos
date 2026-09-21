-- Multi-tenant SaaS expand migration.
--
-- This migration introduces the organization boundary, subscription metadata,
-- entitlement counters, and nullable organization_id columns. It intentionally
-- avoids destructive changes and does not drop legacy global unique constraints
-- or replace existing RLS policies yet. RLS rewrite happens in a later stage.

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

comment on table public.organizations is
  'SaaS tenant boundary. All business data is scoped directly by organization_id or indirectly by branch ownership.';

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

comment on table public.organization_members is
  'Organization-scoped membership and role. Replaces app_users.global_role as the long-term SaaS authorization source.';

create index if not exists organization_members_user_idx
  on public.organization_members (user_id, organization_id);

-- ── Subscription and entitlement metadata ───────────────────────────────────

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
  code,
  name,
  monthly_price,
  yearly_price,
  max_products,
  max_monthly_transactions,
  max_branches_included,
  max_employees_per_paid_branch,
  features
) values
  (
    'free',
    'Free',
    0,
    0,
    50,
    100,
    1,
    0,
    '{"plus_features": false, "advanced_reports": false, "branch_addons": false}'::jsonb
  ),
  (
    'plus',
    'Plus',
    0,
    0,
    500,
    1000,
    1,
    2,
    '{"plus_features": true, "advanced_reports": true, "branch_addons": true}'::jsonb
  )
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

create table if not exists public.branch_subscriptions (
  branch_id uuid primary key references public.branches(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  status text not null check (
    status in ('trialing', 'active', 'past_due', 'canceled', 'expired')
  ),
  billing_period text check (billing_period in ('monthly', 'yearly')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  provider text not null default 'manual',
  provider_subscription_id text,
  included_employee_slots integer not null default 2
    check (included_employee_slots >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists branch_subscriptions_org_idx
  on public.branch_subscriptions (organization_id, status);

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

create table if not exists public.entitlement_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  created_by uuid references public.app_users(id) on delete set null
);

create index if not exists entitlement_events_org_time_idx
  on public.entitlement_events (organization_id, created_at desc);

-- ── Nullable tenant columns for expand phase ────────────────────────────────

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

alter table public.company_settings
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.company_settings
  drop constraint if exists company_settings_singleton;

alter table public.pending_invitations
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.customer_point_ledger
  add column if not exists organization_id uuid references public.organizations(id);

-- ── Backfill existing single-tenant data into one default organization ──────

do $$
declare
  default_org_id uuid;
  default_owner_id uuid;
  default_org_name text;
begin
  select id
    into default_org_id
    from public.organizations
   order by created_at asc
   limit 1;

  select id
    into default_owner_id
    from public.app_users
   order by case when global_role = 'owner' then 0 else 1 end, created_at asc
   limit 1;

  select coalesce(
           (select name from public.branches order by created_at asc limit 1),
           'Default Organization'
         )
    into default_org_name;

  if default_org_id is null and (
    exists (select 1 from public.branches)
    or exists (select 1 from public.app_users)
    or exists (select 1 from public.products)
    or exists (select 1 from public.customers)
  ) then
    insert into public.organizations (
      name,
      business_type,
      owner_user_id,
      trial_ends_at
    ) values (
      default_org_name,
      'fnb',
      default_owner_id,
      now() + interval '30 days'
    )
    returning id into default_org_id;
  end if;

  if default_org_id is null then
    return;
  end if;

  update public.branches
     set organization_id = default_org_id
   where organization_id is null;

  update public.branches
     set is_main = true
   where id = (
     select id
       from public.branches
      where organization_id = default_org_id
      order by created_at asc
      limit 1
   );

  update public.products
     set organization_id = default_org_id
   where organization_id is null;

  update public.categories
     set organization_id = default_org_id
   where organization_id is null;

  update public.customers
     set organization_id = default_org_id
   where organization_id is null;

  update public.option_groups
     set organization_id = default_org_id
   where organization_id is null;

  update public.options o
     set organization_id = coalesce(og.organization_id, default_org_id)
    from public.option_groups og
   where o.group_id = og.id
     and o.organization_id is null;

  update public.options
     set organization_id = default_org_id
   where organization_id is null;

  update public.product_option_groups pog
     set organization_id = coalesce(p.organization_id, og.organization_id, default_org_id)
    from public.products p, public.option_groups og
   where pog.product_id = p.id
     and pog.option_group_id = og.id
     and pog.organization_id is null;

  update public.product_option_groups
     set organization_id = default_org_id
   where organization_id is null;

  update public.bank_accounts
     set organization_id = default_org_id
   where organization_id is null;

  update public.company_settings
     set organization_id = default_org_id
   where organization_id is null;

  update public.pending_invitations
     set organization_id = default_org_id
   where organization_id is null;

  update public.customer_point_ledger cpl
     set organization_id = coalesce(c.organization_id, default_org_id)
    from public.customers c
   where cpl.customer_id = c.id
     and cpl.organization_id is null;

  update public.customer_point_ledger
     set organization_id = default_org_id
   where organization_id is null;

  insert into public.organization_members (
    organization_id,
    user_id,
    role,
    status
  )
  select
    default_org_id,
    au.id,
    case au.global_role
      when 'owner' then 'owner'
      when 'manager' then 'manager'
      else 'cashier'
    end,
    case when au.is_active then 'active' else 'inactive' end
  from public.app_users au
  on conflict (organization_id, user_id) do update set
    role = excluded.role,
    status = excluded.status,
    updated_at = now();

  insert into public.organization_subscriptions (
    organization_id,
    plan_code,
    status,
    trial_ends_at,
    current_period_start,
    current_period_end,
    provider
  ) values (
    default_org_id,
    'plus',
    'trialing',
    now() + interval '30 days',
    now(),
    now() + interval '30 days',
    'manual'
  )
  on conflict (organization_id) do nothing;
end $$;

-- ── Indexes for tenant-scoped reads and future unique constraints ───────────

create index if not exists branches_organization_idx
  on public.branches (organization_id, is_active);

create unique index if not exists branches_one_main_per_org_uq
  on public.branches (organization_id)
  where is_main and organization_id is not null;

create index if not exists products_organization_idx
  on public.products (organization_id, is_active);

create unique index if not exists products_org_sku_uq
  on public.products (organization_id, lower(sku))
  where organization_id is not null and sku is not null;

create index if not exists categories_organization_idx
  on public.categories (organization_id, is_active, sort_order);

create unique index if not exists categories_org_name_uq
  on public.categories (organization_id, lower(name))
  where organization_id is not null;

create index if not exists customers_organization_idx
  on public.customers (organization_id, updated_at desc);

create unique index if not exists customers_org_phone_uq
  on public.customers (organization_id, phone)
  where organization_id is not null and phone is not null;

create index if not exists option_groups_organization_idx
  on public.option_groups (organization_id, sort_order);

create index if not exists options_organization_idx
  on public.options (organization_id, group_id, sort_order);

create index if not exists product_option_groups_organization_idx
  on public.product_option_groups (organization_id, product_id);

create index if not exists bank_accounts_organization_idx
  on public.bank_accounts (organization_id, is_active, display_order);

create index if not exists company_settings_organization_idx
  on public.company_settings (organization_id);

create unique index if not exists company_settings_organization_uq
  on public.company_settings (organization_id)
  where organization_id is not null;

create index if not exists pending_invitations_organization_idx
  on public.pending_invitations (organization_id, lower(email));

create index if not exists customer_point_ledger_organization_idx
  on public.customer_point_ledger (organization_id, created_at desc);

-- ── Organization-aware helper functions for later RLS rewrite ───────────────

create or replace function public.current_user_is_org_member(p_organization_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.organization_members om
     where om.user_id = auth.uid()
       and om.organization_id = p_organization_id
       and om.status = 'active'
  );
$$;

create or replace function public.current_user_org_role(p_organization_id uuid)
returns text
language sql stable security definer
set search_path = public
as $$
  select om.role
    from public.organization_members om
   where om.user_id = auth.uid()
     and om.organization_id = p_organization_id
     and om.status = 'active'
   limit 1;
$$;

create or replace function public.branch_org_id(p_branch_id uuid)
returns uuid
language sql stable security definer
set search_path = public
as $$
  select b.organization_id
    from public.branches b
   where b.id = p_branch_id;
$$;

create or replace function public.current_user_can_manage_org(p_organization_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(public.current_user_org_role(p_organization_id), '')
    in ('owner', 'admin');
$$;

create or replace function public.current_user_can_manage_branch(p_branch_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select
    coalesce(public.current_user_org_role(b.organization_id), '') in ('owner', 'admin')
    or exists (
      select 1
        from public.user_branch_access uba
       where uba.user_id = auth.uid()
         and uba.branch_id = p_branch_id
         and uba.role_at_branch = 'manager'
    )
  from public.branches b
  where b.id = p_branch_id;
$$;

create or replace function public.current_user_has_branch_access(p_branch_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.user_branch_access uba
     where uba.user_id = auth.uid()
       and uba.branch_id = p_branch_id
  )
  or exists (
    select 1
      from public.branches b
      join public.organization_members om
        on om.organization_id = b.organization_id
     where b.id = p_branch_id
       and om.user_id = auth.uid()
       and om.status = 'active'
       and om.role in ('owner', 'admin')
  );
$$;

-- ── RLS for new SaaS tables only. Legacy table policy rewrite is stage 3. ───

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.organization_subscriptions enable row level security;
alter table public.branch_subscriptions enable row level security;
alter table public.usage_counters enable row level security;
alter table public.entitlement_events enable row level security;

drop policy if exists organizations_member_select on public.organizations;
create policy organizations_member_select on public.organizations
  for select to authenticated
  using (public.current_user_is_org_member(id));

drop policy if exists organizations_admin_update on public.organizations;
create policy organizations_admin_update on public.organizations
  for update to authenticated
  using (public.current_user_can_manage_org(id))
  with check (public.current_user_can_manage_org(id));

drop policy if exists organization_members_select on public.organization_members;
create policy organization_members_select on public.organization_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.current_user_can_manage_org(organization_id)
  );

drop policy if exists organization_members_admin_write on public.organization_members;
create policy organization_members_admin_write on public.organization_members
  for all to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

drop policy if exists subscription_plans_read on public.subscription_plans;
create policy subscription_plans_read on public.subscription_plans
  for select to authenticated
  using (is_active);

drop policy if exists organization_subscriptions_select on public.organization_subscriptions;
create policy organization_subscriptions_select on public.organization_subscriptions
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

drop policy if exists organization_subscriptions_admin_write on public.organization_subscriptions;
create policy organization_subscriptions_admin_write on public.organization_subscriptions
  for all to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

drop policy if exists branch_subscriptions_select on public.branch_subscriptions;
create policy branch_subscriptions_select on public.branch_subscriptions
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

drop policy if exists branch_subscriptions_admin_write on public.branch_subscriptions;
create policy branch_subscriptions_admin_write on public.branch_subscriptions
  for all to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

drop policy if exists usage_counters_select on public.usage_counters;
create policy usage_counters_select on public.usage_counters
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

drop policy if exists usage_counters_admin_write on public.usage_counters;
create policy usage_counters_admin_write on public.usage_counters
  for all to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

drop policy if exists entitlement_events_select on public.entitlement_events;
create policy entitlement_events_select on public.entitlement_events
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

drop policy if exists entitlement_events_admin_insert on public.entitlement_events;
create policy entitlement_events_admin_insert on public.entitlement_events
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));
