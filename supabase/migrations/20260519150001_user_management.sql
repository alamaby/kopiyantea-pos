-- FEAT-006 — user management infrastructure.
--
-- 1. Add `email` column to `app_users` so we can match invitees by email
--    at first sign-in (auth.users.email is the only stable link until
--    the user's auth.uid is created on signup).
-- 2. Create `pending_invitations` table — owner-only writes; invitee can
--    read their own row by email match.
-- 3. RLS policies for both, gated on `user_global_role() = 'owner'`.

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS email TEXT;

CREATE INDEX IF NOT EXISTS idx_app_users_email
  ON app_users(LOWER(email))
  WHERE email IS NOT NULL;

CREATE TABLE pending_invitations (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  global_role TEXT NOT NULL CHECK (global_role IN ('owner','manager','cashier')),
  branch_ids_csv TEXT NOT NULL DEFAULT '',
  invited_by UUID REFERENCES app_users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pending_invitations_email
  ON pending_invitations(LOWER(email));

COMMENT ON TABLE pending_invitations IS
  'Pre-auth user record. At invitee first sign-in, the client reads this '
  'by email, creates the matching app_users + user_branch_access rows '
  'with auth.uid, then deletes the invitation.';

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE pending_invitations ENABLE ROW LEVEL SECURITY;

-- Owner can read/write all invitations.
CREATE POLICY pending_invitations_owner_all ON pending_invitations
  FOR ALL TO authenticated
  USING (user_global_role() = 'owner')
  WITH CHECK (user_global_role() = 'owner');

-- Authenticated users can read invitations matching their own email
-- (case-insensitive) so the first-time sign-in claim flow works on the
-- invitee's device.
CREATE POLICY pending_invitations_self_read ON pending_invitations
  FOR SELECT TO authenticated
  USING (
    LOWER(email) = LOWER(
      COALESCE(
        (SELECT email FROM auth.users WHERE id = auth.uid()),
        ''
      )
    )
  );

-- Authenticated users can delete their own invitation as part of the claim
-- (the client deletes after fanning out into app_users + user_branch_access).
CREATE POLICY pending_invitations_self_claim ON pending_invitations
  FOR DELETE TO authenticated
  USING (
    LOWER(email) = LOWER(
      COALESCE(
        (SELECT email FROM auth.users WHERE id = auth.uid()),
        ''
      )
    )
  );

-- ── app_users self-claim insert policy ──────────────────────────────────────
-- When a freshly-signed-up invitee creates their app_users row at claim time,
-- the row's id must equal auth.uid() and the email must match auth.users.email.
-- Owner can already insert via existing policy from migration 010.

CREATE POLICY app_users_self_claim_insert ON app_users
  FOR INSERT TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND LOWER(COALESCE(email, '')) = LOWER(
      COALESCE(
        (SELECT email FROM auth.users WHERE id = auth.uid()),
        ''
      )
    )
  );

-- ── user_branch_access self-claim insert ───────────────────────────────────
-- Invitee can insert their own access rows at claim time iff a matching
-- pending_invitations row exists carrying the branch_id (CSV contains check).

CREATE POLICY uba_self_claim_insert ON user_branch_access
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM pending_invitations pi
       WHERE LOWER(pi.email) = LOWER(
              COALESCE(
                (SELECT email FROM auth.users WHERE id = auth.uid()),
                ''
              )
            )
         AND (',' || pi.branch_ids_csv || ',') LIKE
             ('%,' || user_branch_access.branch_id::text || ',%')
    )
  );
