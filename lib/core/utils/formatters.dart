import 'package:intl/intl.dart';

/// Locale-aware formatters. All Rupiah amounts in the app should go through
/// [formatRupiah] — never via raw `toString()` or hard-coded `Rp ${n}`.

final NumberFormat _idr = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String formatRupiah(num amount) => _idr.format(amount);

final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
final DateFormat _date = DateFormat('d MMM yyyy', 'id_ID');
final DateFormat _time = DateFormat('HH:mm', 'id_ID');

String formatDateTime(DateTime dt) => _dateTime.format(dt);
String formatDate(DateTime dt) => _date.format(dt);
String formatTime(DateTime dt) => _time.format(dt);
