# ADR-0009: Two-Level Discount System

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

Real-world POS discounting comes in two clearly different kinds, and conflating them produces wrong receipts and wrong tax:

1. **Per-product standing discount** ("happy hour 10% off all coffee at Branch A until 18:00"). This belongs to the catalog and applies automatically when an item is added to the cart.
2. **Per-transaction manual discount** ("regular customer, give them Rp 5.000 off"). This is entered by the cashier at checkout and applies to the whole basket.

These two interact with **tax** differently in Indonesian practice:

- Standing discount changes the unit selling price. It is fully absorbed into the line item; the tax base on that line is already the discounted price.
- Manual discount applies after the line subtotal. The tax base on the whole transaction becomes `subtotal − manualDiscountAmount`.

Mixing them into one "discount" field loses the audit trail and produces ambiguous receipts.

## Decision

Implement two distinct discount levels with crisp semantics, both reflected in the schema (Section 7 of the master prompt) and in pure pricing functions (Section 7.3).

**LEVEL 2 — Branch standing discount.**
- Lives on `branch_products.discount_percentage` + `branch_products.discount_valid_until`.
- Applied at line-item creation by `effectiveUnitPrice(...)` (ADR-0011).
- Result is stored in `transaction_items.price_snapshot`. The line subtotal `qty × price_snapshot` already includes it.

**LEVEL 1 — Manual checkout discount.**
- Entered at checkout; rupiah amount (not percentage), to keep cashier math obvious.
- Stored on `transactions.discount_amount`.
- Subtracted from the basket subtotal before tax:
  ```
  base = subtotal − manualDiscountAmount
  taxAmount = base × (taxPercentage / 100)        // exclusive
  total = base + taxAmount
  ```
  (Inclusive case in `computeTotals`, master prompt §7.3.)

Naming convention in code: `discountAmount` always refers to LEVEL 1; LEVEL 2 lives inside `price_snapshot` and is invisible at the totals layer.

## Consequences

**Positive:**
- Receipts are unambiguous: each line shows the already-discounted unit price; the basket shows a single manual discount line.
- Tax base is well-defined and matches Indonesian PB1 expectations.
- Audit retrievable: LEVEL 2 contribution is reconstructible as `(price_override ?? base_price) − price_snapshot` per line (subject to the caveat in Section 14 risk #12).
- Pure functions (`effectiveUnitPrice`, `computeTotals`) are unit-testable in isolation.

**Negative:**
- Two concepts the cashier UI must keep visually distinct. Mitigated by ARB strings (Diskon Item vs Diskon Transaksi).
- A future "promotions engine" (LEVEL 3 — time-based promos, BOGO, bundles, coupons) doesn't fit into either bucket and requires its own table. Explicitly deferred (Section 14 risk #8).

## Alternatives Considered

- **Single `discount_amount` column.** Rejected: loses the line/transaction distinction and the audit trail.
- **Single `discount_percentage` column on transactions.** Rejected: same problem, plus percentage-of-basket is harder to verbally negotiate at the counter than a rupiah amount.
- **Discount as a synthetic negative line item.** Sometimes used in retail POS; rejected here because it muddles the tax base calculation and complicates void/refund logic.
- **Apply LEVEL 1 after tax.** Rejected: misaligns with Indonesian standard; we apply before tax (master prompt §7.3).
