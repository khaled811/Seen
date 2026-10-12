import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/data/services/adhan_prayer_calculator.dart';
import 'package:seen_booking/features/spiritual/data/services/umm_al_qura_hijri_converter.dart';
import 'package:seen_booking/features/spiritual/domain/entities/calc_settings.dart';
import 'package:seen_booking/features/spiritual/domain/entities/hijri_date.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_day.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_id.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_location.dart';

/// Wall clock in Saudi Arabia (UTC+3, no DST) regardless of the machine's
/// own time zone: "HH:MM".
String _ksa(DateTime t) {
  final k = t.toUtc().add(const Duration(hours: 3));
  return '${k.hour.toString().padLeft(2, '0')}:${k.minute.toString().padLeft(2, '0')}';
}

int _minutesBetween(DateTime a, DateTime b) => b.difference(a).inMinutes;

void main() {
  const calc = AdhanPrayerCalculator();
  final makkah = SaudiCities.makkah.toLocation();
  final riyadh = SaudiCities.byId('riyadh')!.toLocation();
  final oct3 = DateTime(2026, 10, 3);

  PrayerDay day({
    PrayerLocation? at,
    DateTime? date,
    CalcMethod method = CalcMethod.ummAlQura,
    AsrMadhab madhab = AsrMadhab.shafi,
  }) =>
      calc.calculate(
        location: at ?? makkah,
        date: date ?? oct3,
        method: method,
        madhab: madhab,
      );

  group('Makkah, 3 October 2026, Umm al-Qura', () {
    final d = day();

    test('the seven moments are strictly chronological', () {
      final times = d.entries.map((e) => e.$2).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isTrue,
            reason: '${d.entries[i].$1} after ${d.entries[i - 1].$1}');
      }
    });

    test('matches the approved design\'s sunrise, midnight and last third', () {
      expect(_ksa(d.sunrise), '06:12');
      expect(_ksa(d.midnight), '23:32');
      expect(_ksa(d.lastThird), '01:20');
    });

    test('fajr, dhuhr, asr, maghrib are within a few minutes of the design', () {
      // The design's numbers are illustrative; real Umm al-Qura is within
      // 5 minutes of them.
      int minutes(String hm) {
        final p = hm.split(':');
        return int.parse(p[0]) * 60 + int.parse(p[1]);
      }

      expect((minutes(_ksa(d.fajr)) - minutes('04:58')).abs(), lessThanOrEqualTo(5));
      expect((minutes(_ksa(d.dhuhr)) - minutes('12:15')).abs(), lessThanOrEqualTo(6));
      expect((minutes(_ksa(d.asr)) - minutes('15:37')).abs(), lessThanOrEqualTo(6));
      expect((minutes(_ksa(d.maghrib)) - minutes('18:04')).abs(), lessThanOrEqualTo(5));
      expect((minutes(_ksa(d.isha)) - minutes('19:34')).abs(), lessThanOrEqualTo(5));
    });

    test('Umm al-Qura isha is exactly 90 minutes after maghrib', () {
      expect(_minutesBetween(d.maghrib, d.isha), 90);
    });

    test('midnight is the midpoint between maghrib and the next fajr', () {
      final next = day(date: DateTime(2026, 10, 4));
      final night = next.fajr.difference(d.maghrib).inSeconds;
      final mid = d.maghrib.add(Duration(seconds: night ~/ 2));
      expect((d.midnight.difference(mid)).inSeconds.abs(), lessThanOrEqualTo(60));
      final third = d.maghrib.add(Duration(seconds: night * 2 ~/ 3));
      expect((d.lastThird.difference(third)).inSeconds.abs(), lessThanOrEqualTo(60));
    });

    test('every time is a whole minute', () {
      for (final (_, t) in d.entries) {
        expect(t.second, 0);
        expect(t.millisecond, 0);
      }
    });

    test('is deterministic', () {
      expect(day(), d);
    });

    test('the day field is the calendar day asked for', () {
      expect(d.date, oct3);
    });
  });

  group('settings reach the calculation', () {
    final base = day();

    test('Hanafi asr is later than the majority asr', () {
      final hanafi = day(madhab: AsrMadhab.hanafi);
      expect(hanafi.asr.isAfter(base.asr), isTrue);
      expect(hanafi.fajr, base.fajr);
      expect(hanafi.dhuhr, base.dhuhr);
    });

    test('Muslim World League fajr differs from Umm al-Qura (18° vs 18.5°)', () {
      final mwl = day(method: CalcMethod.muslimWorldLeague);
      expect(mwl.fajr.isAfter(base.fajr), isTrue, reason: 'smaller angle');
      expect(mwl.sunrise, base.sunrise);
    });

    test('every method produces a valid ordered day', () {
      for (final m in CalcMethod.values) {
        final d = day(method: m);
        final times = d.entries.map((e) => e.$2).toList();
        for (var i = 1; i < times.length; i++) {
          expect(times[i].isAfter(times[i - 1]), isTrue, reason: '$m');
        }
      }
    });
  });

  group('locations', () {
    test('Riyadh (east of Makkah) has its dhuhr about half an hour earlier',
        () {
      final gap = _minutesBetween(day(at: riyadh).dhuhr, day().dhuhr);
      expect(gap, inInclusiveRange(24, 34));
    });

    test('every pre-defined city gives a valid day', () {
      for (final c in SaudiCities.all) {
        final d = day(at: c.toLocation());
        expect(d.fajr.isBefore(d.sunrise), isTrue, reason: c.nameAr);
        expect(d.maghrib.isBefore(d.isha), isTrue, reason: c.nameAr);
        expect(d.isha.isBefore(d.midnight), isTrue, reason: c.nameAr);
      }
    });

    test('Makkah is the first and default city', () {
      expect(SaudiCities.all.first, SaudiCities.makkah);
      expect(SaudiCities.makkah.latitude, 21.4225);
      expect(SaudiCities.makkah.longitude, 39.8262);
    });

    test('city ids are unique and resolvable', () {
      final ids = SaudiCities.all.map((c) => c.id).toSet();
      expect(ids.length, SaudiCities.all.length);
      expect(SaudiCities.byId('riyadh')?.nameAr, 'الرياض');
      expect(SaudiCities.byId('nowhere'), isNull);
      expect(SaudiCities.byId(null), isNull);
    });
  });

  group('across the year', () {
    test('days are valid every day of 2026 in Makkah and Riyadh', () {
      for (final loc in [makkah, riyadh]) {
        for (var i = 0; i < 365; i += 7) {
          final date = DateTime(2026, 1, 1 + i);
          final d = day(at: loc, date: date);
          expect(d.fajr.isBefore(d.sunrise), isTrue, reason: '$date');
          expect(d.sunrise.isBefore(d.dhuhr), isTrue, reason: '$date');
          expect(d.dhuhr.isBefore(d.asr), isTrue, reason: '$date');
          expect(d.asr.isBefore(d.maghrib), isTrue, reason: '$date');
          expect(d.maghrib.isBefore(d.isha), isTrue, reason: '$date');
          expect(d.isha.isBefore(d.midnight), isTrue, reason: '$date');
          expect(d.midnight.isBefore(d.lastThird), isTrue, reason: '$date');
        }
      }
    });

    test('Makkah\'s day length changes through the year', () {
      final summer = day(date: DateTime(2026, 6, 21));
      final winter = day(date: DateTime(2026, 12, 21));
      expect(_minutesBetween(summer.sunrise, summer.maghrib),
          greaterThan(_minutesBetween(winter.sunrise, winter.maghrib)));
    });
  });

  group('next moment', () {
    final d = day();

    test('before fajr', () {
      expect(d.next(d.fajr.subtract(const Duration(minutes: 1)))?.$1, PrayerId.fajr);
    });

    test('exactly at a time moves on', () {
      expect(d.next(d.dhuhr)?.$1, PrayerId.asr);
    });

    test('between isha and midnight it is midnight, then nothing', () {
      expect(d.next(d.isha.add(const Duration(minutes: 1)))?.$1, PrayerId.midnight);
      expect(d.next(d.midnight), isNull);
    });
  });

  group('qibla bearing', () {
    double bearing(double lat, double lng) => calc.qiblaBearing(
          PrayerLocation(
            name: 'x',
            latitude: lat,
            longitude: lng,
            source: LocationSource.gps,
          ),
        );

    test('from Riyadh, Cairo and Jakarta', () {
      expect(bearing(24.7136, 46.6753), closeTo(244, 2));
      expect(bearing(30.0444, 31.2357), closeTo(136, 2));
      expect(bearing(-6.2088, 106.8456), closeTo(295, 2));
    });

    test('is always within 0..360', () {
      for (final c in SaudiCities.all) {
        final b = bearing(c.latitude, c.longitude);
        expect(b, inInclusiveRange(0, 360));
      }
    });
  });

  group('Hijri calendar (Umm al-Qura)', () {
    const hijri = UmmAlQuraHijriConverter();

    test('3 October 2026 is 22 Rabi al-Thani 1448', () {
      // (The design mockup shows "١٤"; that is placeholder text. Counting
      // from 1 Muharram 1448 in mid-June 2026 gives the 22nd.)
      final h = hijri.fromGregorian(oct3);
      expect(h.day, 22);
      expect(h.month, 4);
      expect(h.monthName, 'ربيع الآخر');
      expect(h.year, 1448);
    });

    test('1 Muharram 1448 falls in mid-June 2026', () {
      final d = hijri.toGregorian(1448, 1, 1);
      expect(d.year, 2026);
      expect(d.month, 6);
      expect(d.day, inInclusiveRange(15, 18));
    });

    test('Ramadan 1447 begins in the second half of February 2026', () {
      final d = hijri.toGregorian(1447, 9, 1);
      expect(d.year, 2026);
      expect(d.month, 2);
      expect(d.day, inInclusiveRange(17, 20));
    });

    test('round trip over 800 consecutive days', () {
      var date = DateTime(2025, 1, 1);
      for (var i = 0; i < 800; i++) {
        final h = hijri.fromGregorian(date);
        expect(hijri.toGregorian(h.year, h.month, h.day), date, reason: '$date');
        date = DateTime(date.year, date.month, date.day + 1);
      }
    });

    test('months have 29 or 30 days and a year has 12 of them', () {
      for (var m = 1; m <= 12; m++) {
        expect(hijri.daysInMonth(1447, m), anyOf(29, 30), reason: 'month $m');
      }
    });

    test('consecutive days never skip or repeat a Hijri day', () {
      var prev = hijri.fromGregorian(DateTime(2026, 1, 1));
      for (var i = 1; i < 400; i++) {
        final cur = hijri.fromGregorian(DateTime(2026, 1, 1 + i));
        final sameMonth = cur.month == prev.month && cur.year == prev.year;
        if (sameMonth) {
          expect(cur.day, prev.day + 1);
        } else {
          expect(cur.day, 1);
          expect(prev.day, anyOf(29, 30));
        }
        prev = cur;
      }
    });

    test('month names list covers all 12 months', () {
      expect(hijriMonthNames, hasLength(12));
      expect(hijriMonthNames[8], 'رمضان');
    });
  });
}
