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
final DateFormat _dateTimeSeconds =
    DateFormat('EEEE, d MMMM yyyy HH:mm:ss', 'id_ID');
final DateFormat _date = DateFormat('d MMM yyyy', 'id_ID');
final DateFormat _dayDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
final DateFormat _time = DateFormat('HH:mm', 'id_ID');

String formatDateTime(DateTime dt) => _dateTime.format(dt);
String formatDateTimeSeconds(DateTime dt) => _dateTimeSeconds.format(dt);
String formatDate(DateTime dt) => _date.format(dt);
String formatDayDate(DateTime dt) => _dayDate.format(dt);
String formatTime(DateTime dt) => _time.format(dt);

/// Coarse "berapa lama lalu" untuk timestamp di masa lampau. Untuk
/// elapsed > 7 hari jatuh ke tanggal absolut. Bahasa: Indonesia.
String formatRelativeTime(DateTime dt, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(dt);
  if (diff.isNegative) return formatDateTime(dt);
  if (diff.inSeconds < 60) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'kemarin';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return formatDate(dt);
}
