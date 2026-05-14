# ADR-0011: Discount from Price Override

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

A branch can both **override the price** of a product (`branch_products.price_override`) and **apply a standing discount** to it (`branch_products.discount_percentage`). The question is: when both are set, what is the unit price actually charged?

Two plausible orders:

- **A.** Discount applies to the *override*: `effective = price_override × (1 − discount%)`.
- **B.** Discount applies to the *base*, override replaces the base only when discount is absent.

These produce different rupiah amounts and different audit interpretations. We need one explicit, documented rule that the pricing function, the receipts, the reports, and the cashier UI all agree on.

## Decision

**Discount applies to the override.** Formally, the canonical implementation (master prompt §7.3):

```dart
double effectiveUnitPrice({
  required double basePrice,
  double? priceOverride,
  required double discountPercentage,
  DateTime? discountValidUntil,
  required DateTime now,
}) {
  final priceBeforeDiscount = priceOverride ?? basePrice;
  final discountActive = discountValidUntil == null || discountValidUntil.isAfter(now);
  final effectiveDiscount = discountActive ? discountPercentage : 0;
  return priceBeforeDiscount * (1 - effectiveDiscount / 100);
}
```

Result is what gets stored in `transaction_items.price_snapshot`. The line subtotal `qty × price_snapshot` reflects both the override and the LEVEL 2 standing discount; the LEVEL 1 manual checkout discount (ADR-0009) is layered on top at the transaction level.

`discount_valid_until` is treated as a hard expiry; once past, discount becomes 0 even if `discount_percentage` is non-zero. `now` is provided by the caller (testable, allows the receipt-reprint case to use the original sale time).

## Consequences

**Positive:**
- One pure function; trivially unit-testable.
- Cashier intuition holds: "10% off the price we're showing on the menu."
- Reports comparing realized price vs catalog price line up: `price_snapshot ≤ (price_override ?? base_price)` always.

**Negative:**
- Audit retrieval of "discount given" from the saved row depends on master data still being available — see Section 14 risk #12. If `price_override` changes after the sale, retrospective discount math diverges. Mitigation: add `discount_applied_snapshot` if/when audit becomes critical; currently deferred.
- The cashier UI must show the pre-discount price struck through next to the discounted price to keep the math visible. Design covers this with the `AppBadge` + accent amber pattern (master prompt §6.7 rule 4).

## Alternatives Considered

- **Option B (discount applies to base, override wins when discount is zero).** Rejected: violates cashier intuition; the override price is what the cashier sees on screen, so the discount should come off that.
- **Stack discount × override × catalog base in some weighted way.** Rejected as needlessly clever.
- **Disallow setting both `price_override` and `discount_percentage` on the same `branch_products` row.** Considered but rejected: too restrictive for real promo scenarios ("our local price is X, this week 10% off").
