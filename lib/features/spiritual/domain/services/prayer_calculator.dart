import '../entities/calc_settings.dart';
import '../entities/prayer_day.dart';
import '../entities/prayer_location.dart';

/// Offline astronomical prayer-time calculation.
abstract interface class PrayerCalculator {
  /// Times for the calendar day of [date] at [location]. Pure and
  /// deterministic: the same inputs always give the same result.
  PrayerDay calculate({
    required PrayerLocation location,
    required DateTime date,
    required CalcMethod method,
    required AsrMadhab madhab,
  });

  /// Compass bearing of the Kaaba from [location], degrees clockwise from
  /// north.
  double qiblaBearing(PrayerLocation location);
}
