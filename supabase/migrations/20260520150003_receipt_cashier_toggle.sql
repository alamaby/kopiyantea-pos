-- FEAT-014b — opt-in cashier name on receipt.
-- Non-destructive per ADR-0008. Defaults to true so existing receipts gain
-- accountability without owner opt-in.

alter table public.receipt_settings
  add column if not exists show_cashier_name boolean not null default true;

comment on column public.receipt_settings.show_cashier_name is
  'When true, the receipt prints "Kasir: <fullName>" in the meta header. '
  'Owners can disable per-branch.';
