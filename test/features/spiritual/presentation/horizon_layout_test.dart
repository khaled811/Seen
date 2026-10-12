
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/calc_settings.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_day.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_id.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_location.dart';
import 'package:seen_booking/features/spiritual/presentation/prayer/horizon_card.dart';
import 'package:seen_booking/features/spiritual/presentation/prayer/horizon_layout.dart';

import '../support/prayer_fakes.dart';

PrayerDay _day() => FixedPrayerCalculator().calculate(
      location: SaudiCities.makkah.toLocation(),
      date: DateTime(2026, 10, 3),
      method: CalcMethod.ummAlQura,
      madhab: AsrMadhab.shafi,
    );

void main() {
  final day = _day();
  HorizonLayout at(DateTime reference) => HorizonLayout.compute(day, reference);
  HorizonMarker marker(HorizonLayout l, PrayerId id) =>
      l.markers.firstWhere((m) => m.id == id);

  final noon = DateTime(2026, 10, 3, 11, 40); // 35 min before dhuhr

  group('time axis (right to left)', () {
    final l = at(noon);

    test('has one marker per moment, in order', () {
      expect(l.markers.map((m) => m.id), PrayerId.values);
    });

    test('x decreases as time advances: fajr rightmost, midnight leftmost', () {
      for (var i = 1; i < l.markers.length; i++) {
        expect(l.markers[i].x, lessThan(l.markers[i - 1].x));
      }
    });

    test('every marker stays inside the 12…330 track', () {
      for (final m in l.markers) {
        expect(m.x, inInclusiveRange(HorizonLayout.left, HorizonLayout.right));
      }
    });

    test('reproduces the design\'s positions', () {
      // Design artboard: fajr 318.6, sunrise 299, dhuhr 204.6, asr 149.3,
      // maghrib 110.3, isha 86.5, midnight 23.7.
      expect(marker(l, PrayerId.fajr).x, closeTo(318.6, 2));
      expect(marker(l, PrayerId.sunrise).x, closeTo(299, 2));
      expect(marker(l, PrayerId.dhuhr).x, closeTo(204.6, 3));
      expect(marker(l, PrayerId.asr).x, closeTo(149.3, 3));
      expect(marker(l, PrayerId.maghrib).x, closeTo(110.3, 2));
      expect(marker(l, PrayerId.isha).x, closeTo(86.5, 2));
      expect(marker(l, PrayerId.midnight).x, closeTo(23.7, 3));
    });
  });

  group('daylight arc', () {
    final l = at(noon);

    test('sunrise and maghrib sit on the baseline', () {
      expect(marker(l, PrayerId.sunrise).y, closeTo(HorizonLayout.baselineY, 0.01));
      expect(marker(l, PrayerId.maghrib).y, closeTo(HorizonLayout.baselineY, 0.01));
    });

    test('dhuhr is at the apex (y = 20)', () {
      expect(marker(l, PrayerId.dhuhr).y, closeTo(HorizonLayout.apexY, 2));
    });

    test('asr is on the way down (design: y ≈ 46)', () {
      expect(marker(l, PrayerId.asr).y, closeTo(46, 4));
    });

    test('night moments sit on the baseline', () {
      for (final id in [PrayerId.fajr, PrayerId.isha, PrayerId.midnight]) {
        expect(marker(l, id).y, HorizonLayout.baselineY);
      }
    });

    test('markers on the arc are never below the baseline or above the apex', () {
      for (final m in l.markers) {
        expect(m.y, inInclusiveRange(HorizonLayout.apexY - 1, HorizonLayout.baselineY));
      }
    });

    test('control point puts the apex of the curve at y = 20', () {
      expect(HorizonLayout.controlY, -56);
      const mid = 0.25 * 96 + 0.5 * HorizonLayout.controlY + 0.25 * 96;
      expect(mid, HorizonLayout.apexY);
    });
  });

  group('the sun', () {
    test('before sunrise there is no sun and none of the arc is elapsed', () {
      final l = at(DateTime(2026, 10, 3, 5, 30));
      expect(l.sun, isNull);
      expect(l.elapsedFraction, 0);
    });

    test('at 11:40 the sun is on the arc just before the apex (design: 212.6, 20.5)',
        () {
      final l = at(noon);
      expect(l.sun, isNotNull);
      expect(l.sun!.dx, closeTo(212.6, 4));
      expect(l.sun!.dy, closeTo(20.5, 2));
      expect(l.elapsedFraction, inInclusiveRange(0.4, 0.5));
    });

    test('after maghrib the arc is fully elapsed and the sun is gone', () {
      final l = at(DateTime(2026, 10, 3, 20));
      expect(l.sun, isNull);
      expect(l.elapsedFraction, 1);
    });

    test('moves right to left as the day goes on', () {
      final a = at(DateTime(2026, 10, 3, 9)).sun!;
      final b = at(DateTime(2026, 10, 3, 14)).sun!;
      expect(b.dx, lessThan(a.dx));
    });

    test('the elapsed arc ends exactly where the sun is', () {
      final l = at(noon);
      final (start, _, end) = l.elapsedArc;
      expect(start.dx, closeTo(l.sunriseX, 0.001));
      expect(start.dy, HorizonLayout.baselineY);
      expect(end.dx, closeTo(l.sun!.dx, 0.01));
      expect(end.dy, closeTo(l.sun!.dy, 0.01));
    });

    test('a fully elapsed arc ends at maghrib', () {
      final l = at(DateTime(2026, 10, 3, 21));
      final (_, _, end) = l.elapsedArc;
      expect(end, Offset(l.maghribX, HorizonLayout.baselineY));
    });
  });

  group('past vs future markers', () {
    test('at 11:40 only fajr and sunrise are past', () {
      final l = at(noon);
      expect(
        l.markers.where((m) => m.past).map((m) => m.id),
        [PrayerId.fajr, PrayerId.sunrise],
      );
    });

    test('a reference at the end of the day makes everything past', () {
      final l = at(DateTime(2026, 10, 4));
      expect(l.markers.every((m) => m.past), isTrue);
    });

    test('a reference before the day makes nothing past', () {
      final l = at(DateTime(2026, 10, 2, 23, 59));
      expect(l.markers.any((m) => m.past), isFalse);
    });

    test('exactly at a prayer time that prayer counts as past', () {
      final l = at(day.dhuhr);
      expect(marker(l, PrayerId.dhuhr).past, isTrue);
      expect(marker(l, PrayerId.asr).past, isFalse);
    });
  });

  test('layout is deterministic and value-comparable', () {
    expect(at(noon), at(noon));
  });

  group('tap resolution (markers overlap)', () {
    final l = at(noon);
    Offset centre(PrayerId id) => Offset(marker(l, id).x, marker(l, id).y);

    test('fajr and sunrise are closer than one tap target apart', () {
      final gap = (centre(PrayerId.fajr) - centre(PrayerId.sunrise)).distance;
      expect(gap, lessThan(40), reason: 'their 40 dp targets would overlap');
    });

    test('tapping a marker own centre always selects that marker', () {
      for (final m in l.markers) {
        expect(nearestMarker(l.markers, Offset(m.x, m.y)), m.id);
      }
    });

    test('between two close markers the nearer one wins', () {
      final f = centre(PrayerId.fajr);
      final s = centre(PrayerId.sunrise);
      expect(nearestMarker(l.markers, Offset.lerp(f, s, 0.25)!), PrayerId.fajr);
      expect(nearestMarker(l.markers, Offset.lerp(f, s, 0.75)!), PrayerId.sunrise);
    });

    test('a tap far from every marker selects nothing', () {
      expect(nearestMarker(l.markers, const Offset(120, 0)), isNull);
    });
  });
}
