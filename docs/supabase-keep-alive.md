# Supabase Keep-Alive

The production and development Supabase free-tier projects are kept active by
GitHub Actions workflows:

- `.github/workflows/supabase-ping.yml`
- `.github/workflows/supabase-ping-dev.yml`

The workflows call the `keep-alive` Edge Function. The function checks Auth,
PostgREST, Storage, and the `keep_alive_ping` RPC. The RPC performs a real
Postgres query so Supabase activity detection sees database activity, not only
gateway health checks.

## Components

- `supabase/migrations/20260702000000_keep_alive_rpc.sql` creates
  `public.keep_alive_ping()`.
- `supabase/functions/keep-alive/index.ts` exposes the Edge Function probe.
- `supabase/config.toml` disables JWT verification only for `keep-alive` so
  GitHub Actions can invoke it with the publishable key.
- The workflows call Supabase Management API restore when raw auth health looks
  paused or unreachable.

## Required GitHub Secrets

Production workflow:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_PAT`

Development workflow:

- `SUPABASE_DEV_URL`
- `SUPABASE_DEV_PUBLISHABLE_KEY`
- `SUPABASE_DEV_PROJECT_REF`
- `SUPABASE_DEV_PAT`

`SUPABASE_PROJECT_REF` is the project ref from the dashboard URL:
`https://supabase.com/dashboard/project/<project-ref>`.

`SUPABASE_PAT` is a Supabase personal access token from:
`https://supabase.com/dashboard/account/tokens`.

## Deployment

Apply the migration to both projects before deploying the function:

```bash
supabase db push --project-ref <prod-project-ref>
supabase db push --project-ref <dev-project-ref>
```

Deploy the Edge Function to both projects:

```bash
supabase functions deploy keep-alive --project-ref <prod-project-ref>
supabase functions deploy keep-alive --project-ref <dev-project-ref>
```

The platform injects `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEYS`
(JSON, keyed by key name) into the function environment — no manual secret
wiring needed. Confirm they exist under Edge Functions → Secrets if the
function reports them missing.

If using the Supabase dashboard instead of CLI, run the migration SQL in SQL
Editor for each project, then deploy the function with the CLI.

## Manual Verification

Test the RPC directly:

```bash
curl -X POST "$SUPABASE_URL/rest/v1/rpc/keep_alive_ping" \
  -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Test the Edge Function:

```bash
curl -X POST "$SUPABASE_URL/functions/v1/keep-alive" \
  -H "Authorization: Bearer $SUPABASE_PUBLISHABLE_KEY"
```

Expected result: HTTP 200 with `ok: true` and `checks.database.status` in the
2xx range.

## Troubleshooting

- If the workflow fails with `keep-alive Edge Function failed`, check that the
  function was deployed and `supabase/config.toml` includes `verify_jwt = false`.
- If `checks.database.status` is 404, apply the migration that creates
  `keep_alive_ping`.
- If auto-unpause fails, rotate or recreate the Supabase PAT and verify the
  project ref secret.
