import 'package:hijri/hijri_calendar.dart';

import '../../domain/entities/hijri_date.dart';
import '../../domain/services/hijri_converter.dart';

/// Umm al-Qura calendar via the `hijri` package (tables for 1356–1500 AH).
class UmmAlQuraHijriConverter implements HijriConverter {
  const UmmAlQuraHijriConverter();

  @override
  HijriDate fromGregorian(DateTime date) {
    final h = HijriCalendar.fromDate(date);
    return HijriDate(
      day: h.hDay,
      month: h.hMonth,
      monthName: hijriMonthNames[h.hMonth - 1],
      year: h.hYear,
    );
  }

  @override
  DateTime toGregorian(int year, int month, int day) {
    final g = HijriCalendar().hijriToGregorian(year, month, day);
    return DateTime(g.year, g.month, g.day);
  }

  @override
  int daysInMonth(int year, int month) =>
      HijriCalendar().getDaysInMonth(year, month);
}
