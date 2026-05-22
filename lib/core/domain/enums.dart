/// Application-wide domain enums.
/// All enum names serialise to their camelCase string via EnumNameConverter in Drift.
library;

enum GlobalRole { owner, manager, cashier }

enum BranchRole { manager, cashier }

enum MovementType { purchase, sale, adjustment, waste, transfer }

enum StockUnit { gram, kg, ml, liter, pcs }

enum PaymentMethod { cash, qris, debit, credit, transfer, other }

enum TransactionStatus { completed, voided }

enum OutboxStatus { pending, processing, failed, done }

enum OutboxEntityType {
  transaction,
  transactionItem,
  inventoryMovement,
  customer,
  // FEAT-004 — branch tax settings update.
  branch,
  // FEAT-005 — inventory item create/update + standalone (non-tx) movements.
  inventoryItem,
  // FEAT-006 — user/access management + pending invitations.
  appUser,
  userBranchAccess,
  pendingInvitation,
  // FEAT-001 — modifier system master writes.
  optionGroup,
  optionItem,
  productOptionGroup,
  // FEAT-014 — per-branch receipt template/settings.
  receiptSetting,
  // Opsi C (seed sync) — chain-wide catalog + per-branch overrides + recipes
  // are pushed to Supabase via outbox so first-device seed data appears in
  // server tables (otherwise transaction FKs reject sync).
  product,
  branchProduct,
  productRecipe,
  // FEAT-015 — global bank accounts for transfer payment.
  bankAccount,
  // Tier 1 — product category registry sync.
  category,
}
