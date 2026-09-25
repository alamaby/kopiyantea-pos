-- RLS hardening (non-destructive, ADR-0007).
-- Apply AFTER 20260925000001. Manual apply via Dashboard SQL Editor on
-- staging first, then prod. No data changes.
-- Verified: app calls only claim_invitation_code via sb.rpc (authenticated);
-- no anon call to user_global_role()/user_has_branch_access() in lib/.

-- ── 1. Pin search_path on trigger functions ─────────────────────────────────
create or replace function public.reconcile_cached_stock()
returns trigger
language plpgsql
set search_path = public
as $function$
BEGIN
  UPDATE inventory_items
     SET cached_stock = cached_stock + NEW.delta_signed,
         updated_at   = NOW()
   WHERE id = NEW.inventory_item_id;
  RETURN NEW;
END;
$function$;

create or replace function public.stamp_server_received_at()
returns trigger
language plpgsql
set search_path = public
as $function$
BEGIN
  IF NEW.server_received_at IS NULL THEN
    NEW.server_received_at := NOW();
  END IF;
  RETURN NEW;
END;
$function$;

-- ── 2. Revoke anon EXECUTE on SECURITY DEFINER helpers ──────────────────────
-- Keep authenticated EXECUTE (invite-claim + RLS policies need it).
revoke execute on function public.user_global_role() from anon;
revoke execute on function public.user_has_branch_access(uuid) from anon;

-- ── 3. Tighten owner policies to authenticated (logic unchanged) ────────────
drop policy if exists "bank_accounts owner insert" on public.bank_accounts;
create policy "bank_accounts owner insert" on public.bank_accounts
  for insert to authenticated with check (user_global_role() = 'owner');

drop policy if exists "bank_accounts owner update" on public.bank_accounts;
create policy "bank_accounts owner update" on public.bank_accounts
  for update to authenticated using (user_global_role() = 'owner');

drop policy if exists "bank_accounts owner delete" on public.bank_accounts;
create policy "bank_accounts owner delete" on public.bank_accounts
  for delete to authenticated using (user_global_role() = 'owner');

drop policy if exists "categories owner insert" on public.categories;
create policy "categories owner insert" on public.categories
  for insert to authenticated with check (user_global_role() = 'owner');

drop policy if exists "categories owner update" on public.categories;
create policy "categories owner update" on public.categories
  for update to authenticated using (user_global_role() = 'owner');

drop policy if exists "categories owner delete" on public.categories;
create policy "categories owner delete" on public.categories
  for delete to authenticated using (user_global_role() = 'owner');

-- Auth dashboard (manual, no SQL): enable Leaked Password Protection
-- (HaveIBeenPwned) under Authentication → Policies.
