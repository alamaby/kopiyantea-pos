-- Row Level Security helper functions (ADR-0007, master prompt §8.1).
-- Marked STABLE SECURITY DEFINER so they can be invoked from any policy.

CREATE OR REPLACE FUNCTION user_has_branch_access(p_branch_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_branch_access
     WHERE user_id = auth.uid()
       AND branch_id = p_branch_id
  );
$$;

COMMENT ON FUNCTION user_has_branch_access(UUID) IS
  'TRUE when the current auth.uid() has a user_branch_access row for the given branch.';

CREATE OR REPLACE FUNCTION user_global_role() RETURNS TEXT
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT global_role FROM app_users WHERE id = auth.uid();
$$;

COMMENT ON FUNCTION user_global_role() IS
  'Returns the current user''s app_users.global_role: owner, manager, or cashier.';
