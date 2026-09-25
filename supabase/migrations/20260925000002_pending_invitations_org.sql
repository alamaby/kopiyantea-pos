-- Pending invitations org columns (non-destructive, ADR-0008).
-- Complements repo file 20260617_invite_code_expand.sql which adds
-- join_code/invite_type/max_uses/used_count/status/expires_at + claim RPC.
-- This file only ensures the two columns that file assumes but prod lacks:
-- organization_id + updated_at. Apply AFTER 20260925000001 (organizations
-- must exist) and BEFORE 20260617_invite_code_expand.sql.
-- Idempotent: all statements use IF NOT EXISTS.

alter table public.pending_invitations
  add column if not exists organization_id uuid references public.organizations(id);

alter table public.pending_invitations
  add column if not exists updated_at timestamptz not null default now();

create index if not exists pending_invitations_organization_idx
  on public.pending_invitations (organization_id);

-- NOTE: join_code / invite_type / max_uses / used_count / status / expires_at
-- are defined in 20260617_invite_code_expand.sql — do not duplicate here.
-- That file also creates pending_invitations_org_code_uq +
-- pending_invitations_code_idx + claim_invitation_code RPC.
