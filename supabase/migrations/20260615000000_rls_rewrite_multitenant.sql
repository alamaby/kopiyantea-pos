-- Multi-tenant RLS rewrite (Stage 3).
-- Replaces all single-tenant policies with organization-aware ones.
-- Must run AFTER 20260613110000_multi_tenant_saas_expand.sql.

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 1 — Drop legacy single-tenant policies
-- ═══════════════════════════════════════════════════════════════════════════════

drop policy if exists branches_select            on public.branches;
drop policy if exists branches_write             on public.branches;

drop policy if exists app_users_select           on public.app_users;
drop policy if exists app_users_insert           on public.app_users;
drop policy if exists app_users_update_self      on public.app_users;
drop policy if exists app_users_delete_owner     on public.app_users;

drop policy if exists uba_select                 on public.user_branch_access;
drop policy if exists uba_write                  on public.user_branch_access;

drop policy if exists products_select_all        on public.products;
drop policy if exists products_write_owner       on public.products;

drop policy if exists branch_products_select     on public.branch_products;
drop policy if exists branch_products_write      on public.branch_products;

drop policy if exists inventory_items_select     on public.inventory_items;
drop policy if exists inventory_items_write      on public.inventory_items;

drop policy if exists inv_movements_select       on public.inventory_movements;
drop policy if exists inv_movements_insert       on public.inventory_movements;

drop policy if exists product_recipes_select     on public.product_recipes;
drop policy if exists product_recipes_write      on public.product_recipes;

drop policy if exists customers_select_all       on public.customers;
drop policy if exists customers_insert           on public.customers;
drop policy if exists customers_update           on public.customers;
drop policy if exists customers_delete_owner     on public.customers;

drop policy if exists transactions_select        on public.transactions;
drop policy if exists transactions_insert        on public.transactions;

drop policy if exists tx_items_select            on public.transaction_items;
drop policy if exists tx_items_insert            on public.transaction_items;

drop policy if exists receipt_settings_select    on public.receipt_settings;
drop policy if exists receipt_settings_write     on public.receipt_settings;

drop policy if exists "categories read all auth" on public.categories;
drop policy if exists "categories owner insert"  on public.categories;
drop policy if exists "categories owner update"  on public.categories;
drop policy if exists "categories owner delete"  on public.categories;

drop policy if exists "bank_accounts read all auth" on public.bank_accounts;
drop policy if exists "bank_accounts owner insert"  on public.bank_accounts;
drop policy if exists "bank_accounts owner update"  on public.bank_accounts;
drop policy if exists "bank_accounts owner delete"  on public.bank_accounts;

drop policy if exists "company_settings read"       on public.company_settings;
drop policy if exists "company_settings owner insert" on public.company_settings;
drop policy if exists "company_settings owner update" on public.company_settings;
drop policy if exists "company_settings owner delete" on public.company_settings;

drop policy if exists customer_point_ledger_select_all on public.customer_point_ledger;
drop policy if exists customer_point_ledger_insert     on public.customer_point_ledger;
drop policy if exists customer_point_ledger_delete_owner on public.customer_point_ledger;

-- Legacy helper functions are replaced below (wrappers around new helpers).


-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 2 — Enable RLS on tables that never had it
-- ═══════════════════════════════════════════════════════════════════════════════

alter table public.transaction_item_options enable row level security;
alter table public.option_groups           enable row level security;
alter table public.options                 enable row level security;
alter table public.product_option_groups   enable row level security;
alter table public.pending_invitations     enable row level security;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 3 — Rewrite legacy helpers as org-aware wrappers
-- ═══════════════════════════════════════════════════════════════════════════════

create or replace function public.user_has_branch_access(p_branch_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.current_user_has_branch_access(p_branch_id);
$$;

create or replace function public.user_global_role()
returns text
language sql stable security definer
set search_path = public
as $$
  select coalesce(
    (select om.role
       from public.organization_members om
       join public.branches b on b.organization_id = om.organization_id
      where om.user_id = auth.uid()
        and om.status = 'active'
      order by case om.role when 'owner' then 0 when 'admin' then 1 when 'manager' then 2 else 3 end
      limit 1),
    (select au.global_role from public.app_users au where au.id = auth.uid())
  );
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 4 — Organization-aware policies
-- ═══════════════════════════════════════════════════════════════════════════════

-- ┌─ branches (branch-scoped) ─────────────────────────────────────────────────
create policy branches_select on public.branches
  for select to authenticated
  using (
    public.current_user_can_manage_org(organization_id)
    or public.current_user_has_branch_access(id)
  );

create policy branches_write on public.branches
  for all to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

-- ┌─ app_users (special — no org column; membership via organization_members) ─
create policy app_users_select on public.app_users
  for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.organization_members om
       where om.user_id = public.app_users.id
         and om.status = 'active'
         and om.organization_id in (
           select om2.organization_id from public.organization_members om2
            where om2.user_id = auth.uid() and om2.status = 'active'
         )
    )
  );

create policy app_users_insert on public.app_users
  for insert to authenticated
  with check (public.current_user_can_manage_org(
    (select organization_id from public.pending_invitations where email = (select email from auth.users where id = auth.uid()) limit 1)
  ));

create policy app_users_update on public.app_users
  for update to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.organization_members om
       where om.user_id = public.app_users.id
         and om.status = 'active'
         and public.current_user_can_manage_org(om.organization_id)
    )
  )
  with check (
    id = auth.uid()
    or exists (
      select 1 from public.organization_members om
       where om.user_id = public.app_users.id
         and om.status = 'active'
         and public.current_user_can_manage_org(om.organization_id)
    )
  );

create policy app_users_delete on public.app_users
  for delete to authenticated
  using (
    exists (
      select 1 from public.organization_members om
       where om.user_id = public.app_users.id
         and om.status = 'active'
         and public.current_user_can_manage_org(om.organization_id)
    )
  );

-- ┌─ user_branch_access (junction — org via branch) ───────────────────────────
create policy uba_select on public.user_branch_access
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.current_user_can_manage_org(public.branch_org_id(branch_id))
  );

create policy uba_write on public.user_branch_access
  for all to authenticated
  using (public.current_user_can_manage_org(public.branch_org_id(branch_id)))
  with check (public.current_user_can_manage_org(public.branch_org_id(branch_id)));

-- ┌─ products (chain-wide) ────────────────────────────────────────────────────
create policy products_select on public.products
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy products_write on public.products
  for all to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

-- ┌─ categories (chain-wide) ──────────────────────────────────────────────────
create policy categories_select on public.categories
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy categories_insert on public.categories
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy categories_update on public.categories
  for update to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

create policy categories_delete on public.categories
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));

-- ┌─ branch_products (branch-scoped) ──────────────────────────────────────────
create policy branch_products_select on public.branch_products
  for select to authenticated
  using (public.current_user_has_branch_access(branch_id));

create policy branch_products_write on public.branch_products
  for all to authenticated
  using (public.current_user_can_manage_branch(branch_id))
  with check (public.current_user_can_manage_branch(branch_id));

-- ┌─ inventory_items (branch-scoped) ──────────────────────────────────────────
create policy inventory_items_select on public.inventory_items
  for select to authenticated
  using (public.current_user_has_branch_access(branch_id));

create policy inventory_items_write on public.inventory_items
  for all to authenticated
  using (public.current_user_can_manage_branch(branch_id))
  with check (public.current_user_can_manage_branch(branch_id));

-- ┌─ inventory_movements (branch-scoped, append-only) ─────────────────────────
create policy inv_movements_select on public.inventory_movements
  for select to authenticated
  using (public.current_user_has_branch_access(branch_id));

create policy inv_movements_insert on public.inventory_movements
  for insert to authenticated
  with check (
    public.current_user_has_branch_access(branch_id)
    and (created_by is null or created_by = auth.uid())
  );

-- ┌─ product_recipes (branch-scoped) ──────────────────────────────────────────
create policy product_recipes_select on public.product_recipes
  for select to authenticated
  using (public.current_user_has_branch_access(branch_id));

create policy product_recipes_write on public.product_recipes
  for all to authenticated
  using (public.current_user_can_manage_branch(branch_id))
  with check (public.current_user_can_manage_branch(branch_id));

-- ┌─ customers (chain-wide) ───────────────────────────────────────────────────
create policy customers_select on public.customers
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy customers_insert on public.customers
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy customers_update on public.customers
  for update to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

create policy customers_delete on public.customers
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));


-- ┌─ transactions (branch-scoped, append-only) ────────────────────────────────
create policy transactions_select on public.transactions
  for select to authenticated
  using (public.current_user_has_branch_access(branch_id));

create policy transactions_insert on public.transactions
  for insert to authenticated
  with check (
    public.current_user_has_branch_access(branch_id)
    and cashier_id = auth.uid()
  );

-- ┌─ transaction_items (branch-scoped via parent transaction) ─────────────────
create policy tx_items_select on public.transaction_items
  for select to authenticated
  using (
    exists (
      select 1 from public.transactions t
       where t.id = transaction_items.transaction_id
         and public.current_user_has_branch_access(t.branch_id)
    )
  );

create policy tx_items_insert on public.transaction_items
  for insert to authenticated
  with check (
    exists (
      select 1 from public.transactions t
       where t.id = transaction_items.transaction_id
         and public.current_user_has_branch_access(t.branch_id)
         and t.cashier_id = auth.uid()
    )
  );

-- ┌─ transaction_item_options (branch-scoped via parent chain) ────────────────
create policy tx_item_opts_select on public.transaction_item_options
  for select to authenticated
  using (
    exists (
      select 1
        from public.transaction_items ti
        join public.transactions t on t.id = ti.transaction_id
       where ti.id = transaction_item_options.transaction_item_id
         and public.current_user_has_branch_access(t.branch_id)
    )
  );

create policy tx_item_opts_insert on public.transaction_item_options
  for insert to authenticated
  with check (
    exists (
      select 1
        from public.transaction_items ti
        join public.transactions t on t.id = ti.transaction_id
       where ti.id = transaction_item_options.transaction_item_id
         and public.current_user_has_branch_access(t.branch_id)
         and t.cashier_id = auth.uid()
    )
  );

-- ┌─ receipt_settings (branch-scoped) ─────────────────────────────────────────
create policy receipt_settings_select on public.receipt_settings
  for select to authenticated
  using (public.current_user_has_branch_access(branch_id));

create policy receipt_settings_write on public.receipt_settings
  for all to authenticated
  using (public.current_user_can_manage_branch(branch_id))
  with check (public.current_user_can_manage_branch(branch_id));

-- ┌─ bank_accounts (chain-wide) ───────────────────────────────────────────────
create policy bank_accounts_select on public.bank_accounts
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy bank_accounts_insert on public.bank_accounts
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy bank_accounts_update on public.bank_accounts
  for update to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

create policy bank_accounts_delete on public.bank_accounts
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));

-- ┌─ company_settings (chain-wide) ────────────────────────────────────────────
create policy company_settings_select on public.company_settings
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy company_settings_insert on public.company_settings
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy company_settings_update on public.company_settings
  for update to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

create policy company_settings_delete on public.company_settings
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));

-- ┌─ customer_point_ledger (chain-wide) ───────────────────────────────────────
create policy cpl_select on public.customer_point_ledger
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy cpl_insert on public.customer_point_ledger
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy cpl_delete on public.customer_point_ledger
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));

-- ┌─ option_groups (chain-wide) ───────────────────────────────────────────────
create policy option_groups_select on public.option_groups
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy option_groups_insert on public.option_groups
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy option_groups_update on public.option_groups
  for update to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

create policy option_groups_delete on public.option_groups
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));

-- ┌─ options (chain-wide) ─────────────────────────────────────────────────────
create policy options_select on public.options
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy options_insert on public.options
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy options_update on public.options
  for update to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

create policy options_delete on public.options
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));

-- ┌─ product_option_groups (chain-wide) ───────────────────────────────────────
create policy pog_select on public.product_option_groups
  for select to authenticated
  using (public.current_user_is_org_member(organization_id));

create policy pog_insert on public.product_option_groups
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy pog_update on public.product_option_groups
  for update to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

create policy pog_delete on public.product_option_groups
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));

-- ┌─ pending_invitations (chain-wide, owner/admin only) ───────────────────────
create policy pending_invitations_select on public.pending_invitations
  for select to authenticated
  using (public.current_user_can_manage_org(organization_id));

create policy pending_invitations_insert on public.pending_invitations
  for insert to authenticated
  with check (public.current_user_can_manage_org(organization_id));

create policy pending_invitations_update on public.pending_invitations
  for update to authenticated
  using (public.current_user_can_manage_org(organization_id))
  with check (public.current_user_can_manage_org(organization_id));

create policy pending_invitations_delete on public.pending_invitations
  for delete to authenticated
  using (public.current_user_can_manage_org(organization_id));


-- ── End of RLS rewrite ────────────────────────────────────────────────────────
-- All legacy policies replaced with organization-aware equivalents.
-- SaaS tables (organizations, organization_members, subscription_plans,
-- organization_subscriptions, branch_subscriptions, usage_counters,
-- entitlement_events) are NOT touched here — their RLS was set up in the
-- expand migration (20260613110000_multi_tenant_saas_expand.sql).
