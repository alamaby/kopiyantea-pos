-- ============================================================================
-- SaaS RLS Snapshot — KopiyanteaPOS production (snidupbkvmhsqzlvmsqa)
-- Generated: 2026-09-25 (S-01 plan saas-multitenant-server-first)
-- Source: pg_policies (public + storage) + pg_get_functiondef via MCP read-only
-- Supabase CLI: v2.116.0. Migration history: 26 entries (s.d. 20260613110000)
-- Purpose: ROLLBACK reference before any policy change (no staging project).
--   - FUNCTIONS section below is directly executable (verbatim definitions).
--   - POLICIES section is raw JSON reference; to restore a dropped policy,
--     re-run its original migration file (all use DROP IF EXISTS + CREATE),
--     using qual/with_check below to confirm exact pre-change shape.
--   - Contains NO secrets (policy expressions + function bodies only).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SECTION 1 — POLICIES (raw JSON, schemaname/tablename/policyname/permissive/
-- roles/cmd/qual/with_check). 81 rows total.
-- ----------------------------------------------------------------------------
/* POLICIES-JSON-BEGIN
[{"schemaname":"public","tablename":"app_users","policyname":"app_users_delete_owner","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"DELETE","qual":"(user_global_role() = 'owner'::text)","with_check":null},{"schemaname":"public","tablename":"app_users","policyname":"app_users_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"app_users","policyname":"app_users_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"((id = auth.uid()) OR (user_global_role() = 'owner'::text) OR (EXISTS ( SELECT 1\n   FROM (user_branch_access uba1\n     JOIN user_branch_access uba2 ON ((uba1.branch_id = uba2.branch_id)))\n  WHERE ((uba1.user_id = auth.uid()) AND (uba2.user_id = app_users.id)))))"},{"schemaname":"public","tablename":"app_users","policyname":"app_users_self_claim_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"((id = auth.uid()) AND (lower(COALESCE(email, ''::text)) = lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text))))"},{"schemaname":"public","tablename":"app_users","policyname":"app_users_update_self","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"UPDATE","qual":"((id = auth.uid()) OR (user_global_role() = 'owner'::text))","with_check":"((id = auth.uid()) OR (user_global_role() = 'owner'::text))"},{"schemaname":"public","tablename":"bank_accounts","policyname":"bank_accounts owner delete","permissive":"PERMISSIVE","roles":"{public}","cmd":"DELETE","qual":"(user_global_role() = 'owner'::text)","with_check":null},{"schemaname":"public","tablename":"bank_accounts","policyname":"bank_accounts owner insert","permissive":"PERMISSIVE","roles":"{public}","cmd":"INSERT","qual":null,"with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"bank_accounts","policyname":"bank_accounts owner update","permissive":"PERMISSIVE","roles":"{public}","cmd":"UPDATE","qual":"(user_global_role() = 'owner'::text)","with_check":null},{"schemaname":"public","tablename":"bank_accounts","policyname":"bank_accounts read all auth","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"true","with_check":null},{"schemaname":"public","tablename":"branch_products","policyname":"branch_products_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"user_has_branch_access(branch_id)","with_check":null},{"schemaname":"public","tablename":"branch_products","policyname":"branch_products_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"((user_global_role() = 'owner'::text) OR (user_has_branch_access(branch_id) AND (user_global_role() = 'manager'::text)))","with_check":"((user_global_role() = 'owner'::text) OR (user_has_branch_access(branch_id) AND (user_global_role() = 'manager'::text)))"},{"schemaname":"public","tablename":"branch_subscriptions","policyname":"branch_subscriptions_admin_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"current_user_can_manage_org(organization_id)","with_check":"current_user_can_manage_org(organization_id)"},{"schemaname":"public","tablename":"branch_subscriptions","policyname":"branch_subscriptions_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"current_user_is_org_member(organization_id)","with_check":null},{"schemaname":"public","tablename":"branches","policyname":"branches_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"((user_global_role() = 'owner'::text) OR user_has_branch_access(id))","with_check":null},{"schemaname":"public","tablename":"branches","policyname":"branches_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"(user_global_role() = 'owner'::text)","with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"categories","policyname":"categories owner delete","permissive":"PERMISSIVE","roles":"{public}","cmd":"DELETE","qual":"(user_global_role() = 'owner'::text)","with_check":null},{"schemaname":"public","tablename":"categories","policyname":"categories owner insert","permissive":"PERMISSIVE","roles":"{public}","cmd":"INSERT","qual":null,"with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"categories","policyname":"categories owner update","permissive":"PERMISSIVE","roles":"{public}","cmd":"UPDATE","qual":"(user_global_role() = 'owner'::text)","with_check":null},{"schemaname":"public","tablename":"categories","policyname":"categories read all auth","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"true","with_check":null},{"schemaname":"public","tablename":"company_settings","policyname":"company_settings owner delete","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"DELETE","qual":"(user_global_role() = 'owner'::text)","with_check":null},{"schemaname":"public","tablename":"company_settings","policyname":"company_settings owner insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"company_settings","policyname":"company_settings owner update","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"UPDATE","qual":"(user_global_role() = 'owner'::text)","with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"company_settings","policyname":"company_settings read","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"true","with_check":null},{"schemaname":"public","tablename":"customer_point_ledger","policyname":"customer_point_ledger_delete_owner","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"DELETE","qual":"(user_global_role() = 'owner'::text)","with_check":null},{"schemaname":"public","tablename":"customer_point_ledger","policyname":"customer_point_ledger_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"true"},{"schemaname":"public","tablename":"customer_point_ledger","policyname":"customer_point_ledger_select_all","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"true","with_check":null},{"schemaname":"public","tablename":"customers","policyname":"customers_delete_owner","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"DELETE","qual":"(user_global_role() = 'owner'::text)","with_check":null},{"schemaname":"public","tablename":"customers","policyname":"customers_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"true"},{"schemaname":"public","tablename":"customers","policyname":"customers_update","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"UPDATE","qual":"true","with_check":"true"},{"schemaname":"public","tablename":"entitlement_events","policyname":"entitlement_events_admin_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"current_user_can_manage_org(organization_id)"},{"schemaname":"public","tablename":"entitlement_events","policyname":"entitlement_events_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"current_user_is_org_member(organization_id)","with_check":null},{"schemaname":"public","tablename":"inventory_items","policyname":"inventory_items_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"user_has_branch_access(branch_id)","with_check":null},{"schemaname":"public","tablename":"inventory_items","policyname":"inventory_items_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"((user_global_role() = 'owner'::text) OR (user_has_branch_access(branch_id) AND (user_global_role() = 'manager'::text)))","with_check":"((user_global_role() = 'owner'::text) OR (user_has_branch_access(branch_id) AND (user_global_role() = 'manager'::text)))"},{"schemaname":"public","tablename":"inventory_movements","policyname":"inv_movements_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"(user_has_branch_access(branch_id) AND ((created_by IS NULL) OR (created_by = auth.uid())))"},{"schemaname":"public","tablename":"inventory_movements","policyname":"inv_movements_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"user_has_branch_access(branch_id)","with_check":null},{"schemaname":"public","tablename":"option_groups","policyname":"option_groups_select_all","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"true","with_check":null},{"schemaname":"public","tablename":"option_groups","policyname":"option_groups_write_owner","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"(user_global_role() = 'owner'::text)","with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"options","policyname":"options_select_all","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"true","with_check":null},{"schemaname":"public","tablename":"options","policyname":"options_write_owner","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"(user_global_role() = 'owner'::text)","with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"organization_members","policyname":"organization_members_admin_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"current_user_can_manage_org(organization_id)","with_check":"current_user_can_manage_org(organization_id)"},{"schemaname":"public","tablename":"organization_members","policyname":"organization_members_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"((user_id = auth.uid()) OR current_user_can_manage_org(organization_id))","with_check":null},{"schemaname":"public","tablename":"organization_subscriptions","policyname":"organization_subscriptions_admin_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"current_user_can_manage_org(organization_id)","with_check":"current_user_can_manage_org(organization_id)"},{"schemaname":"public","tablename":"organization_subscriptions","policyname":"organization_subscriptions_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"current_user_is_org_member(organization_id)","with_check":null},{"schemaname":"public","tablename":"organizations","policyname":"organizations_admin_update","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"UPDATE","qual":"current_user_can_manage_org(id)","with_check":"current_user_can_manage_org(id)"},{"schemaname":"public","tablename":"organizations","policyname":"organizations_member_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"current_user_is_org_member(id)","with_check":null},{"schemaname":"public","tablename":"pending_invitations","policyname":"pending_invitations_owner_all","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"(user_global_role() = 'owner'::text)","with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"pending_invitations","policyname":"pending_invitations_self_claim","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"DELETE","qual":"(lower(email) = lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text)))","with_check":null},{"schemaname":"public","tablename":"pending_invitations","policyname":"pending_invitations_self_read","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"(lower(email) = lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text)))","with_check":null},{"schemaname":"public","tablename":"product_option_groups","policyname":"pog_select_all","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"true","with_check":null},{"schemaname":"public","tablename":"product_option_groups","policyname":"pog_write_owner","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"(user_global_role() = 'owner'::text)","with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"product_recipes","policyname":"product_recipes_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"user_has_branch_access(branch_id)","with_check":null},{"schemaname":"public","tablename":"product_recipes","policyname":"product_recipes_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"((user_global_role() = 'owner'::text) OR (user_has_branch_access(branch_id) AND (user_global_role() = 'manager'::text)))","with_check":"((user_global_role() = 'owner'::text) OR (user_has_branch_access(branch_id) AND (user_global_role() = 'manager'::text)))"},{"schemaname":"public","tablename":"products","policyname":"products_select_all","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"true","with_check":null},{"schemaname":"public","tablename":"products","policyname":"products_write_owner","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"(user_global_role() = 'owner'::text)","with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"public","tablename":"receipt_settings","policyname":"receipt_settings_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"user_has_branch_access(branch_id)","with_check":null},{"schemaname":"public","tablename":"receipt_settings","policyname":"receipt_settings_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"((user_global_role() = 'owner'::text) OR (user_has_branch_access(branch_id) AND (user_global_role() = 'manager'::text)))","with_check":"((user_global_role() = 'owner'::text) OR (user_has_branch_access(branch_id) AND (user_global_role() = 'manager'::text)))"},{"schemaname":"public","tablename":"subscription_plans","policyname":"subscription_plans_read","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"is_active","with_check":null},{"schemaname":"public","tablename":"transaction_item_options","policyname":"tx_item_options_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"(EXISTS ( SELECT 1\n   FROM (transaction_items ti\n     JOIN transactions t ON ((t.id = ti.transaction_id)))\n  WHERE ((ti.id = transaction_item_options.transaction_item_id) AND user_has_branch_access(t.branch_id) AND (t.cashier_id = auth.uid()))))"},{"schemaname":"public","tablename":"transaction_item_options","policyname":"tx_item_options_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"(EXISTS ( SELECT 1\n   FROM (transaction_items ti\n     JOIN transactions t ON ((t.id = ti.transaction_id)))\n  WHERE ((ti.id = transaction_item_options.transaction_item_id) AND user_has_branch_access(t.branch_id))))"},{"schemaname":"public","tablename":"transaction_items","policyname":"tx_items_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"(EXISTS ( SELECT 1\n   FROM transactions t\n  WHERE ((t.id = transaction_items.transaction_id) AND user_has_branch_access(t.branch_id) AND (t.cashier_id = auth.uid()))))"},{"schemaname":"public","tablename":"transaction_items","policyname":"tx_items_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"(EXISTS ( SELECT 1\n   FROM transactions t\n  WHERE ((t.id = transaction_items.transaction_id) AND user_has_branch_access(t.branch_id))))"},{"schemaname":"public","tablename":"transactions","policyname":"transactions_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"(user_has_branch_access(branch_id) AND (cashier_id = auth.uid()))"},{"schemaname":"public","tablename":"transactions","policyname":"transactions_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"user_has_branch_access(branch_id)","with_check":null},{"schemaname":"public","tablename":"usage_counters","policyname":"usage_counters_admin_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"current_user_can_manage_org(organization_id)","with_check":"current_user_can_manage_org(organization_id)"},{"schemaname":"public","tablename":"usage_counters","policyname":"usage_counters_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"current_user_is_org_member(organization_id)","with_check":null},{"schemaname":"public","tablename":"user_branch_access","policyname":"uba_select","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"SELECT","qual":"((user_id = auth.uid()) OR (user_global_role() = 'owner'::text))","with_check":null},{"schemaname":"public","tablename":"user_branch_access","policyname":"uba_self_claim_insert","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"INSERT","qual":null,"with_check":"((user_id = auth.uid()) AND (EXISTS ( SELECT 1\n   FROM pending_invitations pi\n  WHERE ((lower(pi.email) = lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text))) AND (((','::text || pi.branch_ids_csv) || ','::text) ~~ (('%,'::text || (user_branch_access.branch_id)::text) || ',%'::text))))))"},{"schemaname":"public","tablename":"user_branch_access","policyname":"uba_write","permissive":"PERMISSIVE","roles":"{authenticated}","cmd":"ALL","qual":"(user_global_role() = 'owner'::text)","with_check":"(user_global_role() = 'owner'::text)"},{"schemaname":"storage","tablename":"objects","policyname":"product-images owner delete","permissive":"PERMISSIVE","roles":"{public}","cmd":"DELETE","qual":"((bucket_id = 'product-images'::text) AND (user_global_role() = 'owner'::text))","with_check":null},{"schemaname":"storage","tablename":"objects","policyname":"product-images owner update","permissive":"PERMISSIVE","roles":"{public}","cmd":"UPDATE","qual":"((bucket_id = 'product-images'::text) AND (user_global_role() = 'owner'::text))","with_check":null},{"schemaname":"storage","tablename":"objects","policyname":"product-images owner write","permissive":"PERMISSIVE","roles":"{public}","cmd":"INSERT","qual":null,"with_check":"((bucket_id = 'product-images'::text) AND (user_global_role() = 'owner'::text))"},{"schemaname":"storage","tablename":"objects","policyname":"product-images read","permissive":"PERMISSIVE","roles":"{public}","cmd":"SELECT","qual":"(bucket_id = 'product-images'::text)","with_check":null},{"schemaname":"storage","tablename":"objects","policyname":"qris-images owner delete","permissive":"PERMISSIVE","roles":"{public}","cmd":"DELETE","qual":"((bucket_id = 'qris-images'::text) AND (user_global_role() = 'owner'::text))","with_check":null},{"schemaname":"storage","tablename":"objects","policyname":"qris-images owner update","permissive":"PERMISSIVE","roles":"{public}","cmd":"UPDATE","qual":"((bucket_id = 'qris-images'::text) AND (user_global_role() = 'owner'::text))","with_check":null},{"schemaname":"storage","tablename":"objects","policyname":"qris-images owner write","permissive":"PERMISSIVE","roles":"{public}","cmd":"INSERT","qual":null,"with_check":"((bucket_id = 'qris-images'::text) AND (user_global_role() = 'owner'::text))"},{"schemaname":"storage","tablename":"objects","policyname":"qris-images read","permissive":"PERMISSIVE","roles":"{public}","cmd":"SELECT","qual":"(bucket_id = 'qris-images'::text)","with_check":null},{"schemaname":"storage","tablename":"objects","policyname":"receipt-logos owner delete","permissive":"PERMISSIVE","roles":"{public}","cmd":"DELETE","qual":"((bucket_id = 'receipt-logos'::text) AND (user_global_role() = 'owner'::text))","with_check":null},{"schemaname":"storage","tablename":"objects","policyname":"receipt-logos owner update","permissive":"PERMISSIVE","roles":"{public}","cmd":"UPDATE","qual":"((bucket_id = 'receipt-logos'::text) AND (user_global_role() = 'owner'::text))","with_check":null},{"schemaname":"storage","tablename":"objects","policyname":"receipt-logos owner write","permissive":"PERMISSIVE","roles":"{public}","cmd":"INSERT","qual":null,"with_check":"((bucket_id = 'receipt-logos'::text) AND (user_global_role() = 'owner'::text))"},{"schemaname":"storage","tablename":"objects","policyname":"receipt-logos read","permissive":"PERMISSIVE","roles":"{public}","cmd":"SELECT","qual":"(bucket_id = 'receipt-logos'::text)","with_check":null}]
POLICIES-JSON-END */

-- ----------------------------------------------------------------------------
-- SECTION 2 — FUNCTIONS (verbatim pg_get_functiondef, directly executable)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.branch_org_id(p_branch_id uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select b.organization_id
    from public.branches b
   where b.id = p_branch_id;
$function$
;

CREATE OR REPLACE FUNCTION public.current_user_can_manage_org(p_organization_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(public.current_user_org_role(p_organization_id), '')
    in ('owner', 'admin');
$function$
;

CREATE OR REPLACE FUNCTION public.current_user_has_branch_access(p_branch_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.current_user_is_org_member(p_organization_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
      from public.organization_members om
     where om.user_id = auth.uid()
       and om.organization_id = p_organization_id
       and om.status = 'active'
  );
$function$
;

CREATE OR REPLACE FUNCTION public.reconcile_cached_stock()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE inventory_items
     SET cached_stock = cached_stock + NEW.delta_signed,
         updated_at   = NOW()
   WHERE id = NEW.inventory_item_id;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.stamp_server_received_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.server_received_at IS NULL THEN
    NEW.server_received_at := NOW();
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.user_global_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT global_role FROM app_users WHERE id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.user_has_branch_access(p_branch_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM user_branch_access
     WHERE user_id = auth.uid()
       AND branch_id = p_branch_id
  );
$function$
;
