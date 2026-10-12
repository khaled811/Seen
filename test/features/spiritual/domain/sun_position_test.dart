import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/core/number_format.dart';
import 'package:seen_booking/features/spiritual/data/services/adhan_prayer_calculator.dart';
import 'package:seen_booking/features/spiritual/domain/entities/calc_settings.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_location.dart';
import 'package:seen_booking/features/spiritual/domain/utils/sun_position.dart';

SunPosition _sun(DateTime t) => SunPosition.at(
      latitude: SaudiCities.makkah.latitude,
      longitude: SaudiCities.makkah.longitude,
      time: t,
    );

void main() {
  const calc = AdhanPrayerCalculator();
  final makkah = SaudiCities.makkah.toLocation();

  test('at Makkah\'s solar noon in December the sun is due south and high', () {
    final day = calc.calculate(
      location: makkah,
      date: DateTime(2026, 12, 21),
      method: CalcMethod.ummAlQura,
      madhab: AsrMadhab.shafi,
    );
    final s = _sun(day.dhuhr);
    expect(s.azimuth, closeTo(180, 3));
    // 90° − latitude − |declination| ≈ 90 − 21.4 − 23.4
    expect(s.altitude, closeTo(45.2, 1.5));
    expect(s.isUp, isTrue);
  });

  test('at the March equinox noon the sun is near the zenith-minus-latitude',
      () {
    final day = calc.calculate(
      location: makkah,
      date: DateTime(2026, 3, 20),
      method: CalcMethod.ummAlQura,
      madhab: AsrMadhab.shafi,
    );
    final s = _sun(day.dhuhr);
    expect(s.altitude, closeTo(68.6, 1.5));
    expect(s.azimuth, closeTo(180, 4));
  });

  test('in June at Makkah the noon sun is north of the zenith', () {
    final day = calc.calculate(
      location: makkah,
      date: DateTime(2026, 6, 21),
      method: CalcMethod.ummAlQura,
      madhab: AsrMadhab.shafi,
    );
    final s = _sun(day.dhuhr);
    expect(s.altitude, greaterThan(85), reason: 'almost overhead');
  });

  test('at sunrise on the equinox the sun is on the horizon, due east', () {
    final day = calc.calculate(
      location: makkah,
      date: DateTime(2026, 3, 20),
      method: CalcMethod.ummAlQura,
      madhab: AsrMadhab.shafi,
    );
    final s = _sun(day.sunrise);
    expect(s.altitude.abs(), lessThan(1.2));
    expect(s.azimuth, closeTo(90, 4));
  });

  test('at sunset on the equinox it is on the horizon, due west', () {
    final day = calc.calculate(
      location: makkah,
      date: DateTime(2026, 3, 20),
      method: CalcMethod.ummAlQura,
      madhab: AsrMadhab.shafi,
    );
    final s = _sun(day.maghrib);
    expect(s.altitude.abs(), lessThan(1.2));
    expect(s.azimuth, closeTo(270, 4));
  });

  test('at night the sun is below the horizon', () {
    final day = calc.calculate(
      location: makkah,
      date: DateTime(2026, 10, 3),
      method: CalcMethod.ummAlQura,
      madhab: AsrMadhab.shafi,
    );
    final s = _sun(day.midnight);
    expect(s.altitude, lessThan(-20));
    expect(s.isUp, isFalse);
  });

  test('moves clockwise through the day (east -> south -> west)', () {
    final day = calc.calculate(
      location: makkah,
      date: DateTime(2026, 12, 21),
      method: CalcMethod.ummAlQura,
      madhab: AsrMadhab.shafi,
    );
    final morning = _sun(day.sunrise.add(const Duration(hours: 2))).azimuth;
    final noon = _sun(day.dhuhr).azimuth;
    final evening = _sun(day.maghrib.subtract(const Duration(hours: 2))).azimuth;
    expect(morning, lessThan(noon));
    expect(noon, lessThan(evening));
  });

  test('is independent of the DateTime\'s time zone flag', () {
    final local = DateTime(2026, 10, 3, 12);
    expect(_sun(local).azimuth, closeTo(_sun(local.toUtc()).azimuth, 1e-9));
  });

  group('number formatting', () {
    test('thousands separators in Arabic-Indic digits', () {
      expect(formatThousands(8325), '٨,٣٢٥');
      expect(formatThousands(847.4), '٨٤٧');
      expect(formatThousands(1000), '١,٠٠٠');
      expect(formatThousands(999), '٩٩٩');
      expect(formatThousands(1234567), '١,٢٣٤,٥٦٧');
      expect(formatThousands(0), '٠');
    });

    test('coordinates use the Arabic decimal separator', () {
      expect(formatCoordinate(21.4225, 'ش'), '٢١٫٤٢٢٥° ش');
      expect(formatCoordinate(39.8262, 'ق'), '٣٩٫٨٢٦٢° ق');
      expect(formatCoordinate(-6.2, 'ج', decimals: 1), '٦٫٢° ج');
    });
  });
}
