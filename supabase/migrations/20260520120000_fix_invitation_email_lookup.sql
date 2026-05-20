-- ════════════════════════════════════════════════════════════════════════════
-- 20260520120000 — Fix: invitation policies referenced auth.users directly,
-- but the `authenticated` role doesn't have SELECT on auth.users by default.
-- This caused: "permission denied for table users (code: 42501)" when an
-- authenticated client tried to read/write pending_invitations.
--
-- Fix: read the caller's email from the JWT claim instead — auth.jwt() ->>
-- 'email' is a STABLE function exposed to every authenticated role.
-- ════════════════════════════════════════════════════════════════════════════

-- ── pending_invitations: drop + recreate the three affected policies ────────
DROP POLICY IF EXISTS pending_invitations_self_read ON pending_invitations;
DROP POLICY IF EXISTS pending_invitations_self_claim ON pending_invitations;

CREATE POLICY pending_invitations_self_read ON pending_invitations
  FOR SELECT TO authenticated
  USING (
    LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
  );

CREATE POLICY pending_invitations_self_claim ON pending_invitations
  FOR DELETE TO authenticated
  USING (
    LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
  );

-- ── app_users self-claim insert ─────────────────────────────────────────────
DROP POLICY IF EXISTS app_users_self_claim_insert ON app_users;

CREATE POLICY app_users_self_claim_insert ON app_users
  FOR INSERT TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND LOWER(COALESCE(email, '')) =
        LOWER(COALESCE(auth.jwt() ->> 'email', ''))
  );

-- ── user_branch_access self-claim insert ────────────────────────────────────
DROP POLICY IF EXISTS uba_self_claim_insert ON user_branch_access;

CREATE POLICY uba_self_claim_insert ON user_branch_access
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM pending_invitations pi
       WHERE LOWER(pi.email) =
             LOWER(COALESCE(auth.jwt() ->> 'email', ''))
         AND (',' || pi.branch_ids_csv || ',') LIKE
             ('%,' || user_branch_access.branch_id::text || ',%')
    )
  );
