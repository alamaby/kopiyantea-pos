const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';

/// Publishable key (`sb_publishable_…`) — replacement for the legacy
/// `SUPABASE_ANON_KEY`. Supabase injects `SUPABASE_PUBLISHABLE_KEYS` as JSON
/// keyed by key name (e.g. `{"default": "sb_publishable_…"}`); older CLIs and
/// local setups may still provide the singular `SUPABASE_PUBLISHABLE_KEY` or
/// the legacy `SUPABASE_ANON_KEY`, so resolve in that priority order.
function resolvePublishableKey(): string {
  const plural = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '';
  if (plural !== '') {
    try {
      const parsed: unknown = JSON.parse(plural);
      if (typeof parsed === 'object' && parsed !== null && 'default' in parsed) {
        const key = (parsed as Record<string, unknown>)['default'];
        if (typeof key === 'string' && key !== '') return key;
      }
    } catch {
      // Fall through to the singular / legacy fallbacks below.
    }
  }
  return Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    Deno.env.get('SUPABASE_ANON_KEY') ?? '';
}

const SUPABASE_PUBLISHABLE_KEY = resolvePublishableKey();

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type ProbeResult = {
  status?: number;
  ms: number;
  ok: boolean;
  error?: string;
};

async function probe(
  label: string,
  url: string,
  init: RequestInit,
  isHealthyStatus: (status: number) => boolean = (status) => status < 500,
): Promise<ProbeResult & { label: string; body?: unknown }> {
  const startedAt = Date.now();

  try {
    const response = await fetch(url, init);
    const ms = Date.now() - startedAt;
    const text = await response.text();
    let body: unknown;

    if (text.trim().length > 0) {
      try {
        body = JSON.parse(text);
      } catch (_) {
        body = text.slice(0, 500);
      }
    }

    return {
      label,
      status: response.status,
      ms,
      ok: isHealthyStatus(response.status),
      body,
    };
  } catch (error) {
    return {
      label,
      ms: Date.now() - startedAt,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ ok: false, error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'content-type': 'application/json' },
    });
  }

  if (SUPABASE_URL.length === 0 || SUPABASE_PUBLISHABLE_KEY.length === 0) {
    return new Response(
      JSON.stringify({ ok: false, error: 'SUPABASE_URL or SUPABASE_PUBLISHABLE_KEYS is missing' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'content-type': 'application/json' },
      },
    );
  }

  const startedAt = Date.now();
  // New API keys are opaque (not JWTs) — send only on the `apikey` header,
  // never on `Authorization: Bearer`.
  const baseHeaders = { apikey: SUPABASE_PUBLISHABLE_KEY };

  const auth = await probe('auth', `${SUPABASE_URL}/auth/v1/health`, {
    headers: baseHeaders,
  });

  const rest = await probe('postgrest', `${SUPABASE_URL}/rest/v1/`, {
    headers: baseHeaders,
  });

  const database = await probe('database', `${SUPABASE_URL}/rest/v1/rpc/keep_alive_ping`, {
    method: 'POST',
    headers: {
      ...baseHeaders,
      'content-type': 'application/json',
    },
    body: '{}',
  }, (status) => status >= 200 && status < 300);

  const storage = await probe('storage', `${SUPABASE_URL}/storage/v1/bucket`, {
    headers: baseHeaders,
  });

  const checks = { auth, rest, database, storage };
  const ok = Object.values(checks).every((check) => check.ok);

  return new Response(
    JSON.stringify(
      {
        ok,
        checked_at: new Date().toISOString(),
        total_ms: Date.now() - startedAt,
        checks,
      },
      null,
      2,
    ),
    {
      status: ok ? 200 : 503,
      headers: { ...corsHeaders, 'content-type': 'application/json' },
    },
  );
});
