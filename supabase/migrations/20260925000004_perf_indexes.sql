-- Perf indexes for unindexed FKs (non-destructive).
-- Apply AFTER 20260925000001. No CONCURRENTLY (migration runs in transaction).
-- Covers the 10 get_advisors(performance) unindexed_foreign_keys findings
-- from 2026-09-25. Existing 007 indexes are not touched.

create index if not exists inventory_movements_branch_idx
  on public.inventory_movements (branch_id);

create index if not exists inventory_movements_created_by_idx
  on public.inventory_movements (created_by);

create index if not exists pending_invitations_invited_by_idx
  on public.pending_invitations (invited_by);

create index if not exists product_option_groups_option_group_idx
  on public.product_option_groups (option_group_id);

create index if not exists product_recipes_branch_idx
  on public.product_recipes (branch_id);

create index if not exists product_recipes_inventory_item_idx
  on public.product_recipes (inventory_item_id);

create index if not exists transaction_items_product_idx
  on public.transaction_items (product_id);

create index if not exists transactions_customer_idx
  on public.transactions (customer_id)
  where customer_id is not null;

create index if not exists transactions_voided_by_idx
  on public.transactions (voided_by_transaction_id)
  where voided_by_transaction_id is not null;

create index if not exists user_branch_access_branch_idx
  on public.user_branch_access (branch_id);

-- TODO: manual — auth_rls_initplan (11 policies use auth.uid() per-row).
-- Rewrite each policy's auth.uid() / auth.jwt() / current_setting() as
-- (select auth.uid()) etc. without changing logic. Example pattern:
--   drop policy if exists "app_users_select" on public.app_users;
--   create policy "app_users_select" on public.app_users
--     for select to authenticated using ((select auth.uid()) = id ...);
-- Skipped here because full policy definitions live in prod (pg_policies);
-- generate per-policy DROP/CREATE from
--   SELECT policyname, qual, with_check FROM pg_policies
--   WHERE schemaname='public'
-- and replace auth.<fn>() with (select auth.<fn>()) only.
