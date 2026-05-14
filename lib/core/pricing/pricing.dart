/// Pricing pure functions. See ADR-0009, ADR-0011, ADR-0012.
///
/// These are the canonical implementations referenced by the master prompt §7.3.
/// All inputs are plain Dart scalars — no Flutter, no Drift, no Supabase.
/// Fully unit-tested in `test/core/pricing/pricing_test.dart`.
library;

/// Returns the effective unit price after applying [priceOverride] and the
/// branch standing discount (LEVEL 2).
///
/// - Discount base is [priceOverride] when set, [basePrice] otherwise (ADR-0011).
/// - Discount is skipped when [discountValidUntil] is in the past.
/// - Result is stored in [TransactionItem.priceSnapshot] at checkout.
double effectiveUnitPrice({
  required double basePrice,
  double? priceOverride,
  required double discountPercentage,
  DateTime? discountValidUntil,
  required DateTime now,
}) {
  final priceBeforeDiscount = priceOverride ?? basePrice;
  final discountActive =
      discountValidUntil == null || discountValidUntil.isAfter(now);
  final effectiveDiscount = discountActive ? discountPercentage : 0.0;
  return priceBeforeDiscount * (1 - effectiveDiscount / 100);
}

/// Result of [computeTotals].
typedef TotalsResult = ({
  double subtotal,
  double taxAmount,
  double total,
});

/// Computes (subtotal, taxAmount, total) for a basket.
///
/// [subtotal] is the sum of `qty × price_snapshot` across all items.
/// [manualDiscountAmount] is the LEVEL 1 cashier-entered discount.
///
/// Tax base = subtotal − manualDiscountAmount (Indonesian standard; discount
/// reduces the taxable amount, ADR-0009, ADR-0012).
///
/// For inclusive tax: tax is extracted from the base for display; customer pays
/// [base]. For exclusive tax: tax is added on top.
TotalsResult computeTotals({
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
