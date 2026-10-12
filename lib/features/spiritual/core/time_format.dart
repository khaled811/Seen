import 'arabic_digits.dart';

const _gregorianMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// DateTime.weekday is 1 = Monday .. 7 = Sunday.
const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String gregorianMonthName(int month) => _gregorianMonths[month - 1];

String weekdayName(DateTime date) => _weekdays[date.weekday - 1];

/// "٣ أكتوبر ٢٠٢٦".
String formatGregorianDate(DateTime d) =>
    toArabicDigits('${d.day} ${gregorianMonthName(d.month)} ${d.year}');

/// 12-hour clock with ص/م and Arabic-Indic digits: "١٢:١٥ م".
String formatClock12(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return toArabicDigits('$h:$m ${t.hour < 12 ? 'ص' : 'م'}');
}

/// 12-hour clock without the period marker: "١٢:١٥".
String formatClockShort(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return toArabicDigits('$h:$m');
}

/// "٣٥ د" / "٣ س ٥٧ د" (compact, for badges).
String formatShortSpan(Duration d) {
  final minutes = _ceilMinutes(d);
  if (minutes < 60) return toArabicDigits('$minutes د');
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? toArabicDigits('$h س') : toArabicDigits('$h س $m د');
}

/// "بعد ٣٥ دقيقة" / "بعد ٣ س ٥٧ د".
String formatRelativeFuture(Duration d) {
  final minutes = _ceilMinutes(d);
  if (minutes < 60) return toArabicDigits('بعد $minutes دقيقة');
  return 'بعد ${formatShortSpan(d)}';
}

int _ceilMinutes(Duration d) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = (seconds / 60).ceil();
  return m < 1 ? 1 : m;
}

/// Midnight (00:00) of [d]'s calendar day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar-day arithmetic that is safe across DST changes.
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);
