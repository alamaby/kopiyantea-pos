-- FEAT-002 Phase 8 — atomic organization signup RPC (ADR-0014).
-- The client has no INSERT policy on organizations/organization_members, so
-- the SECOND (and later) organizations must be born through this function.
-- Non-destructive per ADR-0008; grants EXECUTE to authenticated only.

create or replace function public.create_organization_with_owner(
  p_name text,
  p_business_type text default 'generic',
  p_phone text default null,
  p_address text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_now timestamptz := now();
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if p_name is null or btrim(p_name) = '' then
    return json_build_object('ok', false, 'error', 'name_required');
  end if;

  insert into public.organizations (
    name, business_type, phone, address, owner_user_id,
    status, trial_ends_at, created_at, updated_at
  ) values (
    btrim(p_name),
    coalesce(p_business_type, 'generic'),
    nullif(btrim(coalesce(p_phone, '')), ''),
    nullif(btrim(coalesce(p_address, '')), ''),
    auth.uid(),
    'active',
    v_now + interval '30 days',
    v_now,
    v_now
  )
  returning id into v_org_id;

  insert into public.organization_members (
    organization_id, user_id, role, status, created_at, updated_at
  ) values (
    v_org_id, auth.uid(), 'owner', 'active', v_now, v_now
  )
  on conflict (organization_id, user_id) do nothing;

  insert into public.organization_subscriptions (
    organization_id, plan_code, status,
    current_period_start, current_period_end,
    provider, created_at, updated_at
  ) values (
    v_org_id, 'plus', 'trialing',
    v_now, v_now + interval '30 days',
    'manual', v_now, v_now
  )
  on conflict (organization_id) do nothing;

  return json_build_object(
    'ok', true,
    'organization_id', v_org_id,
    'organization_name', btrim(p_name),
    'role', 'owner'
  );
exception
  when others then
    return json_build_object('ok', false, 'error', 'unknown');
end;
$$;

comment on function public.create_organization_with_owner(text, text, text, text) is
  'Atomic signup: creates organization + owner membership + plus trial. '
  'Required because clients hold no INSERT policy on org tables.';

grant execute on function
  public.create_organization_with_owner(text, text, text, text)
  to authenticated;

-- Postgres grants EXECUTE to PUBLIC by default — revoke so only signed-in
-- users can create organizations (matches hardening pattern in 000003).
revoke execute on function
  public.create_organization_with_owner(text, text, text, text)
  from anon, PUBLIC;
