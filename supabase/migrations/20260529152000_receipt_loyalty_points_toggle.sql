-- Receipt visibility toggle for customer loyalty points.
-- Non-destructive per ADR-0008. Defaults preserve existing receipt output.

alter table public.receipt_settings
  add column if not exists show_loyalty_points boolean not null default true;

comment on column public.receipt_settings.show_loyalty_points is
  'When true, payment receipts print earned loyalty points and current customer point balance when available.';
