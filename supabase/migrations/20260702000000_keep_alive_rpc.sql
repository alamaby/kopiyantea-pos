-- Read-only keep-alive probe used by GitHub Actions and the keep-alive
-- Edge Function. It intentionally performs real Postgres work so Supabase
-- free-tier activity detection sees database activity, not only gateway hits.

create or replace function public.keep_alive_ping()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_catalog
as $$
begin
  return jsonb_build_object(
    'server_time', now(),
    'request_id', gen_random_uuid(),
    'db_name', current_database(),
    'pg_version', version()
  );
end;
$$;

comment on function public.keep_alive_ping() is
  'Read-only keep-alive RPC. GitHub Actions calls this through the keep-alive Edge Function to register real database activity for Supabase free-tier projects.';

grant execute on function public.keep_alive_ping() to anon, authenticated;
