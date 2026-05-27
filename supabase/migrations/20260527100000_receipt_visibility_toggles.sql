-- Receipt visibility toggles for customer and branch names.
-- Non-destructive per ADR-0008. Defaults preserve existing receipt output.

alter table public.receipt_settings
  add column if not exists show_customer_name boolean not null default true;

alter table public.receipt_settings
  add column if not exists show_branch_name boolean not null default true;

comment on column public.receipt_settings.show_customer_name is
  'When true, receipts print "Pelanggan: <name>" when a customer is attached. '
  'The app may include a masked phone number in the rendered label.';

comment on column public.receipt_settings.show_branch_name is
  'When true, receipts print the branch display name at the top of the receipt.';
