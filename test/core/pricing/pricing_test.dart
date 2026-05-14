import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/pricing/pricing.dart';

void main() {
  final kNow = DateTime(2026, 5, 14, 12);

  // ──────────────────────────────────────────────────────────
  // effectiveUnitPrice
  // ──────────────────────────────────────────────────────────
  group('effectiveUnitPrice', () {
    test('uses basePrice when no priceOverride', () {
      final result = effectiveUnitPrice(
        basePrice: 30000,
        discountPercentage: 0,
        now: kNow,
      );
      expect(result, 30000.0);
    });

    test('uses priceOverride when provided', () {
      final result = effectiveUnitPrice(
        basePrice: 30000,
        priceOverride: 25000,
        discountPercentage: 0,
        now: kNow,
      );
      expect(result, 25000.0);
    });

    test('discount applies to priceOverride, not basePrice (ADR-0011)', () {
      final result = effectiveUnitPrice(
        basePrice: 30000,
        priceOverride: 25000,
        discountPercentage: 10,
        now: kNow,
      );
      // 25000 × (1 − 0.10) = 22500, not 30000×0.9 = 27000
      expect(result, 22500.0);
    });

    test('discount applies when no expiry set', () {
      final result = effectiveUnitPrice(
        basePrice: 20000,
        discountPercentage: 20,
        discountValidUntil: null,
        now: kNow,
      );
      expect(result, 16000.0);
    });

    test('discount applies when expiry is in the future', () {
      final result = effectiveUnitPrice(
        basePrice: 20000,
        discountPercentage: 20,
        discountValidUntil: kNow.add(const Duration(hours: 1)),
        now: kNow,
      );
      expect(result, 16000.0);
    });

    test('discount skipped when expiry is in the past', () {
      final result = effectiveUnitPrice(
        basePrice: 20000,
        discountPercentage: 20,
        discountValidUntil: kNow.subtract(const Duration(seconds: 1)),
        now: kNow,
      );
      expect(result, 20000.0);
    });

    test('zero discount returns full price', () {
      final result = effectiveUnitPrice(
        basePrice: 15000,
        discountPercentage: 0,
        now: kNow,
      );
      expect(result, 15000.0);
    });

    test('100% discount returns zero', () {
      final result = effectiveUnitPrice(
        basePrice: 15000,
        discountPercentage: 100,
        now: kNow,
      );
      expect(result, 0.0);
    });
  });

  // ──────────────────────────────────────────────────────────
  // computeTotals — exclusive tax (taxInclusive: false)
  // ──────────────────────────────────────────────────────────
  group('computeTotals — exclusive tax', () {
    test('no discount, 10% tax', () {
      final r = computeTotals(
        subtotal: 100000,
        manualDiscountAmount: 0,
        taxPercentage: 10,
        taxInclusive: false,
      );
      expect(r.subtotal, 100000.0);
      expect(r.taxAmount, 10000.0);
      expect(r.total, 110000.0);
    });

    test('discount reduces taxable base (Indonesian standard, ADR-0009)', () {
      final r = computeTotals(
        subtotal: 100000,
        manualDiscountAmount: 10000,
        taxPercentage: 10,
        taxInclusive: false,
      );
      // base = 100000 − 10000 = 90000; tax = 9000; total = 99000
      expect(r.subtotal, 100000.0);
      expect(r.taxAmount, 9000.0);
      expect(r.total, 99000.0);
    });

    test('zero tax percentage', () {
      final r = computeTotals(
        subtotal: 50000,
        manualDiscountAmount: 0,
        taxPercentage: 0,
        taxInclusive: false,
      );
      expect(r.taxAmount, 0.0);
      expect(r.total, 50000.0);
    });

    test('full discount results in zero tax and zero total', () {
      final r = computeTotals(
        subtotal: 50000,
        manualDiscountAmount: 50000,
        taxPercentage: 10,
        taxInclusive: false,
      );
      expect(r.taxAmount, 0.0);
      expect(r.total, 0.0);
    });
  });

  // ──────────────────────────────────────────────────────────
  // computeTotals — inclusive tax (taxInclusive: true)
  // ──────────────────────────────────────────────────────────
  group('computeTotals — inclusive tax', () {
    test('extracts tax from base, total equals base (ADR-0012)', () {
      final r = computeTotals(
        subtotal: 110000,
        manualDiscountAmount: 0,
        taxPercentage: 10,
        taxInclusive: true,
      );
      // base = 110000; extracted tax = 110000 × 10/110 ≈ 10000; total = 110000
      expect(r.subtotal, 110000.0);
      expect(r.taxAmount, closeTo(10000.0, 0.01));
      expect(r.total, 110000.0);
    });

    test('discount reduces base before tax extraction', () {
      final r = computeTotals(
        subtotal: 110000,
        manualDiscountAmount: 11000,
        taxPercentage: 10,
        taxInclusive: true,
      );
      // base = 110000 − 11000 = 99000; tax = 99000 × 10/110 = 9000; total = 99000
      expect(r.taxAmount, closeTo(9000.0, 0.01));
      expect(r.total, 99000.0);
    });

    test('zero tax — tax extracted is zero, total equals base', () {
      final r = computeTotals(
        subtotal: 50000,
        manualDiscountAmount: 0,
        taxPercentage: 0,
        taxInclusive: true,
      );
      expect(r.taxAmount, 0.0);
      expect(r.total, 50000.0);
    });
  });
}
