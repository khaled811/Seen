import 'package:adhan/adhan.dart';

import '../../domain/entities/calc_settings.dart';
import '../../domain/entities/prayer_day.dart';
import '../../domain/entities/prayer_location.dart';
import '../../domain/services/prayer_calculator.dart';

/// Offline calculation with the `adhan` package. Times are absolute instants
/// shown in the device's time zone (rounded to the minute by the package).
class AdhanPrayerCalculator implements PrayerCalculator {
  const AdhanPrayerCalculator();

  @override
  PrayerDay calculate({
    required PrayerLocation location,
    required DateTime date,
    required CalcMethod method,
    required AsrMadhab madhab,
  }) {
    final coordinates = Coordinates(location.latitude, location.longitude);
    final params = _method(method).getParameters()
      ..madhab = madhab == AsrMadhab.hanafi ? Madhab.hanafi : Madhab.shafi;
    final times = PrayerTimes(
      coordinates,
      DateComponents(date.year, date.month, date.day),
      params,
    );
    final sunnah = SunnahTimes(times);
    return PrayerDay(
      date: DateTime(date.year, date.month, date.day),
      fajr: times.fajr,
      sunrise: times.sunrise,
      dhuhr: times.dhuhr,
      asr: times.asr,
      maghrib: times.maghrib,
      isha: times.isha,
      midnight: sunnah.middleOfTheNight,
      lastThird: sunnah.lastThirdOfTheNight,
    );
  }

  @override
  double qiblaBearing(PrayerLocation location) =>
      Qibla(Coordinates(location.latitude, location.longitude)).direction;

  static CalculationMethod _method(CalcMethod m) => switch (m) {
        CalcMethod.ummAlQura => CalculationMethod.umm_al_qura,
        CalcMethod.muslimWorldLeague => CalculationMethod.muslim_world_league,
        CalcMethod.egyptian => CalculationMethod.egyptian,
        CalcMethod.karachi => CalculationMethod.karachi,
        CalcMethod.northAmerica => CalculationMethod.north_america,
      };
}
