import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopiyantea_pos/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    // intl id_ID locale data is initialized in main.dart at runtime — tests
    // must do it explicitly or DateFormat throws "Locale data has not been
    // initialized" on the first call.
    await initializeDateFormatting('id_ID', null);
  });

  group('formatRupiah', () {
    test('zero', () {
      expect(formatRupiah(0), 'Rp 0');
    });

    test('thousands use dot separator (id_ID)', () {
      expect(formatRupiah(25000), 'Rp 25.000');
      expect(formatRupiah(1500000), 'Rp 1.500.000');
    });

    test('billion-scale still readable', () {
      expect(formatRupiah(1234567890), 'Rp 1.234.567.890');
    });

    test('negative amount (refund)', () {
      expect(formatRupiah(-25000), startsWith('-'));
      expect(formatRupiah(-25000), contains('25.000'));
    });

    test('decimal input is rounded — currency has no fractional rupiah', () {
      expect(formatRupiah(25000.4), 'Rp 25.000');
      // intl rounds half-away-from-zero by default
      expect(formatRupiah(25000.5), anyOf('Rp 25.001', 'Rp 25.000'));
    });
  });

  group('formatDateTime / formatDate / formatTime', () {
    final t = DateTime(2026, 5, 22, 14, 30);

    test('formatDateTime returns "d MMM yyyy, HH:mm" in id_ID', () {
      expect(formatDateTime(t), '22 Mei 2026, 14.30');
    });

    test('formatDate returns date only', () {
      expect(formatDate(t), '22 Mei 2026');
    });

    test('formatTime returns time only', () {
      expect(formatTime(t), '14.30');
    });
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 5, 22, 14, 30);

    test('within 60s → "baru saja"', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'baru saja',
      );
    });

    test('minutes ago', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 menit lalu',
      );
    });

    test('hours ago', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 jam lalu',
      );
    });

    test('exactly 1 day ago → "kemarin"', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 1)), now: now),
        'kemarin',
      );
    });

    test('2..6 days ago → "N hari lalu"', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 3)), now: now),
        '3 hari lalu',
      );
    });

    test('older than 7 days → falls back to absolute date', () {
      final old = now.subtract(const Duration(days: 30));
      expect(formatRelativeTime(old, now: now), formatDate(old));
    });

    test('future timestamp → falls back to formatDateTime', () {
      final later = now.add(const Duration(hours: 1));
      expect(formatRelativeTime(later, now: now), formatDateTime(later));
    });
  });
}
