-- Cashier name snapshot — make struk/laporan lama tahan terhadap perubahan
-- atau penghapusan baris di app_users. Matches Drift schemaVersion 11.
-- Append-only column; pre-migration rows keep NULL and the client falls
-- back to a live app_users.full_name lookup at render time.

alter table public.transactions
  add column if not exists cashier_name_snapshot text;

comment on column public.transactions.cashier_name_snapshot is
  'Immutable snapshot of app_users.full_name at checkout time. NULL only '
  'for pre-2026-05-22 rows; the client UI falls back to live lookup in '
  'that case. New transactions must always populate this column.';
