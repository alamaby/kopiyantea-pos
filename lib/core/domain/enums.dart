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
}
