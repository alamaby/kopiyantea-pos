-- ENH-004 — opt-in printing static QRIS image on receipt.
-- Non-destructive per ADR-0008. Default false (most flows complete
-- payment before receipt prints, making the on-receipt QR redundant).

alter table public.receipt_settings
  add column if not exists print_qris_on_receipt boolean not null default false;

comment on column public.receipt_settings.print_qris_on_receipt is
  'When true AND tx.payment_method = qris AND branches.qris_image_url is '
  'set, the print receipt embeds the static QRIS image so the customer '
  'can scan + input nominal manually from the TOTAL. Useful for pay-later '
  'flows (takeaway, delivery, pro-forma).';
