-- Chain-wide receipt logo managed by owner.
-- Non-destructive: legacy per-branch receipt_settings.logo_url remains for
-- backward compatibility, but new clients read/write this singleton row.

create table if not exists public.company_settings (
  id text primary key default 'global',
  receipt_logo_url text,
  show_receipt_logo boolean not null default false,
  receipt_logo_position text not null default 'top'
    check (receipt_logo_position in ('top', 'bottom')),
  updated_at timestamptz not null default now(),
  constraint company_settings_singleton check (id = 'global')
);

comment on table public.company_settings is
  'Chain-wide owner-managed settings shared by all branches.';

comment on column public.company_settings.receipt_logo_url is
  'Global coffee shop logo printed on receipts for every branch.';

do $$
declare
  has_logo_position boolean;
begin
  if to_regclass('public.receipt_settings') is null then
    return;
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'receipt_settings'
      and column_name = 'logo_position'
  ) into has_logo_position;

  execute format(
    'insert into public.company_settings (
       id,
       receipt_logo_url,
       show_receipt_logo,
       receipt_logo_position,
       updated_at
     )
     select
       %L,
       rs.logo_url,
       rs.show_logo,
       %s,
       rs.updated_at
     from public.receipt_settings rs
     where rs.logo_url is not null and btrim(rs.logo_url) <> ''''
     order by rs.updated_at desc
     limit 1
     on conflict (id) do nothing',
    'global',
    case when has_logo_position then 'rs.logo_position' else quote_literal('top') end
  );
end $$;

alter table public.company_settings enable row level security;

drop policy if exists "company_settings read" on public.company_settings;
create policy "company_settings read" on public.company_settings
  for select to authenticated
  using (true);

drop policy if exists "company_settings owner insert" on public.company_settings;
drop policy if exists "company_settings owner update" on public.company_settings;
drop policy if exists "company_settings owner delete" on public.company_settings;

do $$
begin
  if to_regprocedure('public.user_global_role()') is null then
    raise notice 'Skipping company_settings owner write policies because public.user_global_role() does not exist.';
    return;
  end if;

  execute '
    create policy "company_settings owner insert" on public.company_settings
      for insert to authenticated
      with check (public.user_global_role() = ''owner'')
  ';

  execute '
    create policy "company_settings owner update" on public.company_settings
      for update to authenticated
      using (public.user_global_role() = ''owner'')
      with check (public.user_global_role() = ''owner'')
  ';

  execute '
    create policy "company_settings owner delete" on public.company_settings
      for delete to authenticated
      using (public.user_global_role() = ''owner'')
  ';
end $$;
