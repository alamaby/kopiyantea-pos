-- Multi-Org Phase I — Expand pending_invitations for code-based invites
--
-- Adds columnar support for invitation codes (distinct from email-based
-- invites already used by FEAT-006). Code invites are intended for users
-- who already have an account and want to join an existing organization.
--
-- Non-destructive per ADR-0008: all columns are nullable-with-default or
-- added with IF NOT EXISTS.

-- ── New columns ──────────────────────────────────────────────────────────────

alter table public.pending_invitations
  add column if not exists join_code text,
  add column if not exists invite_type text not null default 'email'
    check (invite_type in ('email', 'code')),
  add column if not exists max_uses integer not null default 1
    check (max_uses >= 1),
  add column if not exists used_count integer not null default 0
    check (used_count >= 0),
  add column if not exists status text not null default 'active'
    check (status in ('active', 'consumed', 'canceled')),
  add column if not exists expires_at timestamptz;

-- Backfill existing rows created before this migration.
update public.pending_invitations
   set invite_type = 'email',
       status = 'active'
 where invite_type = 'email'
   and status = 'active';

-- Unique constraint: a code must be unique within its organization.
-- Multiple NULL join_codes (email invites) are allowed per org, so we
-- use NULLS NOT DISTINCT so each (org, null) set is treated as distinct.
-- This requires PostgreSQL ≥ 15 (Supabase default since early 2024).
alter table public.pending_invitations
  add constraint if not exists pending_invitations_org_code_uq
    unique nulls not distinct (organization_id, join_code);

-- Fast lookup when a user submits an 8-char code.
create index if not exists pending_invitations_code_idx
  on public.pending_invitations (join_code)
  where invite_type = 'code';

-- Index for listing active code invites per org (owner/admin dashboard).
create index if not exists pending_invitations_org_code_active_idx
  on public.pending_invitations (organization_id, status, invite_type)
  where invite_type = 'code';

-- ── Claim RPC ────────────────────────────────────────────────────────────────
--
-- SECURITY DEFINER is required because the claimer is not yet an org
-- member and therefore falls under RLS deny-by-default for org-scoped
-- tables. The function is owned by postgres (default) so it can read
-- pending_invitations rows across all orgs and write organization_members.
--
-- Returns JSON:
--   On success: {"ok": true, "organization_id": "...", "organization_name": "...", "role": "..."}
--   On error:   {"ok": false, "error": "not_found"|"expired"|"already_exhausted"|"already_member"}

create or replace function public.claim_invitation_code(
  p_code text,
  p_user_id uuid
)
returns json
language plpgsql
security definer
as $$
declare
  v_inv record;
  v_org_name text;
  v_result json;
begin
  --
  -- 1. Find the active code-based invitation row and lock it so parallel
  --    claims for the same code (e.g. max_uses > 1) are serialized.
  --
  select *
    into v_inv
    from public.pending_invitations
   where join_code = upper(p_code)
     and invite_type = 'code'
     and status = 'active'
     and (expires_at is null or expires_at > now())
   order by created_at asc
   limit 1
   for update;

  -- ── Error: code does not exist ────────────────────────────────────────────
  if v_inv is null then
    v_result := json_build_object('ok', false, 'error', 'not_found');
    return v_result;
  end if;

  -- ── Error: code has expired (defensive; the WHERE already filters) ────────
  if v_inv.expires_at is not null and v_inv.expires_at <= now() then
    v_result := json_build_object('ok', false, 'error', 'expired');
    return v_result;
  end if;

  -- ── Error: all uses have been consumed ────────────────────────────────────
  if v_inv.used_count >= v_inv.max_uses then
    v_result := json_build_object('ok', false, 'error', 'already_exhausted');
    return v_result;
  end if;

  -- ── Error: user is already a member of this org ───────────────────────────
  if exists (
    select 1 from public.organization_members
     where organization_id = v_inv.organization_id
       and user_id = p_user_id
  ) then
    v_result := json_build_object('ok', false, 'error', 'already_member');
    return v_result;
  end if;

  -- ── 2. Fetch organization name for the return payload ─────────────────────
  select name into v_org_name
    from public.organizations
   where id = v_inv.organization_id;

  -- ── 3. Grant membership ───────────────────────────────────────────────────
  insert into public.organization_members (
    organization_id,
    user_id,
    role,
    status,
    created_at,
    updated_at
  ) values (
    v_inv.organization_id,
    p_user_id,
    v_inv.global_role,
    'active',
    now(),
    now()
  )
  on conflict (organization_id, user_id) do update set
    role = excluded.role,
    status = excluded.status,
    updated_at = excluded.updated_at;

  -- ── 4. Grant branch access (from the CSV stored at creation time) ─────────
  --    Each branch_id in branch_ids_csv becomes a user_branch_access row.
  insert into public.user_branch_access (user_id, branch_id, role_at_branch)
  select
    p_user_id,
    trim(bid)::uuid,
    null::text
  from unnest(string_to_array(v_inv.branch_ids_csv, ',')) as bid
  where trim(bid) <> ''
  on conflict (user_id, branch_id) do nothing;

  -- ── 5. Increment consumption counter ──────────────────────────────────────
  update public.pending_invitations
     set used_count = used_count + 1,
         status = case
                    when used_count + 1 >= max_uses then 'consumed'
                    else 'active'
                  end,
         updated_at = now()
   where id = v_inv.id;

  -- ── 6. Build success payload ──────────────────────────────────────────────
  v_result := json_build_object(
    'ok', true,
    'organization_id', v_inv.organization_id,
    'organization_name', coalesce(v_org_name, ''),
    'role', v_inv.global_role
  );

  return v_result;
end;
$$;

comment on function public.claim_invitation_code(text, uuid) is
  'Claim an open invitation code for an existing user. Transaction-safe '  
  'via row-level locking. Does NOT require caller to be an org member.';

-- ── Minimal permissions ──────────────────────────────────────────────────────
-- The function is SECURITY DEFINER but still needs explicit GRANT so
-- authenticated users can invoke it (Postgres default-type functions are
-- executable by PUBLIC, but explicit grant is best-practice).
grant execute on function public.claim_invitation_code(text, uuid)
  to authenticated;
