import '../entities/hijri_date.dart';

/// Umm al-Qura calendar conversion.
abstract interface class HijriConverter {
  HijriDate fromGregorian(DateTime date);

  /// Gregorian date (00:00 local) of a Hijri date.
  DateTime toGregorian(int year, int month, int day);

  int daysInMonth(int year, int month);
}
