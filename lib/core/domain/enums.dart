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
  product,
  branchProduct,
  branch,
  appUser,
  userBranchAccess,
  heldOrder,
  receiptSetting,
  companySetting,
  bankAccount,
  pendingInvitation,
  optionGroup,
  option,
  productOptionGroup,
  category,
  inventoryItem,
  productRecipe,
  shiftClosing,
}

// ── SaaS / Multi-tenant enums (FEAT-002) ────────────────────────────────────

enum BusinessType { generic, fnb, retail, service, other }

enum OrganizationStatus { active, suspended, deleted }

enum OrganizationMemberRole { owner, admin, manager, cashier }

enum OrganizationMemberStatus { active, invited, inactive }

enum SubscriptionStatus { trialing, active, past_due, canceled, expired }

enum SubscriptionPlanCode { free, plus }
