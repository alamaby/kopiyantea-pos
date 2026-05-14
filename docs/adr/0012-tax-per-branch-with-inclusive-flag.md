# ADR-0012: Tax Per Branch with Inclusive Flag

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

Indonesian F&B tax (PB1) is typically 10% but rates and labels vary by region and operator. Within one chain, two branches may legally fall under different rates or different labelling (`PB1` vs `PPN`). Some menus display prices that **already include** tax ("harga sudah termasuk pajak"); others display tax-exclusive prices and add tax on the receipt. The system must support both styles without ambiguity, and historic receipts must remain accurate even when the rate or style changes later.

## Decision

Tax configuration is **per-branch** and **snapshotted onto each transaction at sale time**.

### Schema

On `branches`:
- `tax_percentage NUMERIC NOT NULL DEFAULT 10 CHECK (0..100)`
- `tax_label TEXT NOT NULL DEFAULT 'PB1'`
- `tax_inclusive BOOLEAN NOT NULL DEFAULT FALSE`

On `transactions` (immutable snapshot):
- `tax_percentage_snapshot`
- `tax_label_snapshot`
- `tax_inclusive_snapshot`

### Computation (master prompt §7.3)

```dart
({double subtotal, double taxAmount, double total}) computeTotals({
  required double subtotal,
  required double manualDiscountAmount,
  required double taxPercentage,
  required bool taxInclusive,
}) {
  final base = subtotal - manualDiscountAmount;
  if (taxInclusive) {
    final taxAmount = base * (taxPercentage / (100 + taxPercentage));
    return (subtotal: subtotal, taxAmount: taxAmount, total: base);
  } else {
    final taxAmount = base * (taxPercentage / 100);
    return (subtotal: subtotal, taxAmount: taxAmount, total: base + taxAmount);
  }
}
```

- **Exclusive (default):** tax adds on top of `subtotal − manualDiscount`.
- **Inclusive:** product prices already contain tax; we *extract* the tax for receipt display but the customer pays `base`.

### Tax base

Tax base = `subtotal − manualDiscountAmount` in both modes (Indonesian standard: LEVEL 1 discount reduces taxable amount).

### Snapshotting

At checkout, the cashier app reads the branch's current `tax_percentage` / `tax_label` / `tax_inclusive` and writes them as snapshots into the transaction row. Subsequent rate changes do **not** retroactively alter past receipts.

## Consequences

**Positive:**
- One owner can change a branch's tax rate at any time without rewriting history.
- Receipts always show the rate that was in effect at the moment of sale.
- Two branches can run different tax setups simultaneously.
- The inclusive/exclusive split keeps the math honest; "Rp 25.000 sudah termasuk PB1" prints a coherent receipt showing the extracted tax line.

**Negative:**
- Three columns of tax-snapshot data on every transaction row. Storage cost negligible at POS scale.
- Multi-rate tax (e.g., service charge stacked on PB1) is not yet supported — would require a `tax_components` table. Explicitly deferred (Section 14 risk #5).
- Tax-base interaction with LEVEL 1 discount must be communicated clearly in cashier UX so refunds line up.

## Alternatives Considered

- **Global tax setting on the chain.** Rejected: real branches differ.
- **Per-product tax category.** Common in retail; deferred — F&B in Indonesia rarely needs it within a single establishment, and supporting it requires the deferred multi-component tax engine.
- **No snapshot, recompute from current branch settings.** Rejected: a rate change would silently rewrite history. Unacceptable for financial records.
- **Always exclusive, force menu to display ex-tax prices.** Rejected: forces a UX many owners don't want.
