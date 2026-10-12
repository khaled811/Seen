import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/compass_reading.dart';
import 'package:seen_booking/features/spiritual/domain/utils/angles.dart';
import 'package:seen_booking/features/spiritual/domain/utils/qibla_lock.dart';
import 'package:seen_booking/features/spiritual/domain/utils/qibla_math.dart';

void main() {
  group('normalizeDegrees', () {
    test('wraps into 0..360', () {
      expect(normalizeDegrees(0), 0);
      expect(normalizeDegrees(360), 0);
      expect(normalizeDegrees(370), 10);
      expect(normalizeDegrees(-10), 350);
      expect(normalizeDegrees(-370), 350);
      expect(normalizeDegrees(720.5), closeTo(0.5, 1e-9));
    });
  });

  group('shortestDelta (signed, clockwise positive)', () {
    test('plain differences', () {
      expect(shortestDelta(10, 40), 30);
      expect(shortestDelta(40, 10), -30);
    });

    test('wraps across north in both directions', () {
      expect(shortestDelta(359, 1), 2);
      expect(shortestDelta(1, 359), -2);
      expect(shortestDelta(350, 20), 30);
      expect(shortestDelta(20, 350), -30);
    });

    test('is always within -180..180', () {
      for (var a = 0.0; a < 360; a += 17) {
        for (var b = 0.0; b < 360; b += 13) {
          final d = shortestDelta(a, b);
          expect(d, inInclusiveRange(-180, 180), reason: '$a -> $b');
          expect(normalizeDegrees(a + d), closeTo(normalizeDegrees(b), 1e-9));
        }
      }
    });

    test('exactly opposite is ±180, never beyond', () {
      expect(shortestDelta(0, 180).abs(), 180);
    });

    test('same angle is zero, even a full turn apart', () {
      expect(shortestDelta(90, 90), 0);
      expect(shortestDelta(90, 450), closeTo(0, 1e-9));
    });
  });

  group('lerpAngle', () {
    test('goes the short way round north', () {
      expect(lerpAngle(350, 10, 0.5), closeTo(0, 1e-9));
      expect(lerpAngle(10, 350, 0.5), closeTo(0, 1e-9));
    });

    test('t = 0 and t = 1 are the endpoints', () {
      expect(lerpAngle(30, 100, 0), 30);
      expect(lerpAngle(30, 100, 1), closeTo(100, 1e-9));
      expect(lerpAngle(350, 10, 1), closeTo(10, 1e-9));
    });

    test('never returns outside 0..360', () {
      for (var t = 0.0; t <= 1; t += 0.1) {
        final v = lerpAngle(355, 5, t);
        expect(v, inInclusiveRange(0, 360));
      }
    });
  });

  group('HeadingFilter (low-pass, α = 0.15)', () {
    test('the first sample is taken as is', () {
      final f = HeadingFilter();
      expect(f.add(123), 123);
      expect(f.value, 123);
    });

    test('moves 15% of the way each step', () {
      final f = HeadingFilter()..add(100);
      expect(f.add(200), closeTo(115, 1e-9));
      expect(f.add(200), closeTo(127.75, 1e-9));
    });

    test('converges to a steady input', () {
      final f = HeadingFilter()..add(0);
      var v = 0.0;
      for (var i = 0; i < 60; i++) {
        v = f.add(90);
      }
      expect(v, closeTo(90, 0.01));
    });

    test('noise around north does not swing the needle through 180°', () {
      final f = HeadingFilter()..add(0);
      final seen = <double>[];
      for (var i = 0; i < 40; i++) {
        seen.add(f.add(i.isEven ? 358 : 2));
      }
      for (final v in seen) {
        final off = shortestDelta(0, v).abs();
        expect(off, lessThan(5), reason: 'stayed near north, got $v');
      }
    });

    test('a plain average would have been wrong (sanity check)', () {
      expect((358 + 2) / 2, 180, reason: 'why a naive filter fails at north');
    });

    test('noisy input is damped', () {
      final f = HeadingFilter()..add(100);
      var maxJump = 0.0;
      var prev = 100.0;
      for (final raw in [100, 112, 95, 108, 92, 110, 97, 105]) {
        final v = f.add(raw.toDouble());
        maxJump = maxJump < (v - prev).abs() ? (v - prev).abs() : maxJump;
        prev = v;
      }
      expect(maxJump, lessThan(3), reason: 'raw swings up to 17°');
    });

    test('reset forgets the previous heading', () {
      final f = HeadingFilter()..add(10);
      f.reset();
      expect(f.value, isNull);
      expect(f.add(200), 200);
    });
  });

  group('Qibla bearing', () {
    double bearing(double lat, double lng) => QiblaMath.bearing(lat, lng);

    test('known cities (great-circle initial bearing)', () {
      expect(bearing(24.7136, 46.6753), closeTo(244.6, 1), reason: 'Riyadh');
      expect(bearing(30.0444, 31.2357), closeTo(136.2, 1), reason: 'Cairo');
      expect(bearing(51.5074, -0.1278), closeTo(118.9, 1), reason: 'London');
      expect(bearing(40.7128, -74.0060), closeTo(58.5, 1), reason: 'New York');
      expect(bearing(-6.2088, 106.8456), closeTo(295, 1), reason: 'Jakarta');
      expect(bearing(-33.8688, 151.2093), closeTo(277, 1.5), reason: 'Sydney');
      expect(bearing(21.5433, 39.1728), closeTo(101, 1.5), reason: 'Jeddah');
    });

    test('due south of the Kaaba the bearing is north', () {
      expect(bearing(0, QiblaMath.kaabaLongitude), closeTo(0, 0.01));
    });

    test('due north of the Kaaba the bearing is south', () {
      expect(bearing(50, QiblaMath.kaabaLongitude), closeTo(180, 0.01));
    });

    test('a little west of the Kaaba the bearing is east, a little east it is west',
        () {
      // (Far apart, a great circle bows towards the pole, so test close by.)
      expect(bearing(QiblaMath.kaabaLatitude, 38.8262), closeTo(90, 0.6));
      expect(bearing(QiblaMath.kaabaLatitude, 40.8262), closeTo(270, 0.6));
    });

    test('always within 0..360, including across the date line', () {
      for (var lat = -80.0; lat <= 80; lat += 20) {
        for (var lng = -180.0; lng <= 180; lng += 30) {
          expect(bearing(lat, lng), inInclusiveRange(0, 360));
        }
      }
    });
  });

  group('distance to the Kaaba', () {
    double km(double lat, double lng) => QiblaMath.distanceKm(lat, lng);

    test('known cities', () {
      expect(km(24.7136, 46.6753), closeTo(790, 10), reason: 'Riyadh');
      expect(km(30.0444, 31.2357), closeTo(1286, 20), reason: 'Cairo');
      expect(km(51.5074, -0.1278), closeTo(4790, 60), reason: 'London');
      expect(km(40.7128, -74.0060), closeTo(10300, 120), reason: 'New York');
      expect(km(-6.2088, 106.8456), closeTo(7960, 100), reason: 'Jakarta');
    });

    test('is zero at the Kaaba and below the "near" threshold close by', () {
      expect(km(QiblaMath.kaabaLatitude, QiblaMath.kaabaLongitude), closeTo(0, 1e-6));
      expect(km(21.4225, 39.8262), lessThan(QiblaMath.nearKaabaKm));
      expect(km(21.4850, 39.8262), greaterThan(QiblaMath.nearKaabaKm));
    });

    test('never exceeds half the Earth\'s circumference', () {
      final antipode = km(-QiblaMath.kaabaLatitude, QiblaMath.kaabaLongitude - 180);
      expect(antipode, closeTo(20015, 30));
    });

    test('haversine and the law of cosines agree within 0.5%', () {
      for (final p in const [
        (24.7136, 46.6753),
        (51.5074, -0.1278),
        (40.7128, -74.0060),
        (-33.8688, 151.2093),
        (35.6762, 139.6503),
      ]) {
        final h = QiblaMath.distanceKm(p.$1, p.$2);
        final c = QiblaMath.distanceKmLawOfCosines(p.$1, p.$2);
        expect((h - c).abs() / h, lessThan(0.005), reason: '$p');
      }
    });

    test('is symmetric in the sense that nearby points have similar distances',
        () {
      expect(km(24.0, 46.0), closeTo(km(24.001, 46.001), 1));
    });
  });

  group('QiblaLock hysteresis (lock ±2°, release beyond ±4°)', () {
    test('starts unlocked', () {
      expect(QiblaLock().locked, isFalse);
    });

    test('locks at exactly 2° and not at 2.01°', () {
      expect((QiblaLock()..update(2.01)).locked, isFalse);
      expect((QiblaLock()..update(2.0)).locked, isTrue);
      expect((QiblaLock()..update(-2.0)).locked, isTrue);
      expect((QiblaLock()..update(0)).locked, isTrue);
    });

    test('stays locked up to and including 4°, releases beyond it', () {
      final l = QiblaLock()..update(0);
      for (final off in [2.5, 3.0, 3.99, 4.0, -3.5, -4.0]) {
        expect(l.update(off), isTrue, reason: '$off');
      }
      expect(l.update(4.01), isFalse);
    });

    test('once released it does NOT re-lock between 2° and 4°', () {
      final l = QiblaLock()..update(0);
      l.update(5);
      for (final off in [4.0, 3.0, 2.5, 2.01, -3.0]) {
        expect(l.update(off), isFalse, reason: '$off');
      }
      expect(l.update(2.0), isTrue);
    });

    test('jitter around the lock threshold does not flicker', () {
      final l = QiblaLock();
      final states = <bool>[];
      for (final off in [2.6, 2.1, 1.9, 2.3, 1.8, 2.4, 2.2, 1.95, 2.5, 3.0]) {
        states.add(l.update(off));
      }
      // Exactly one change (false -> true) in the whole noisy sequence.
      var changes = 0;
      for (var i = 1; i < states.length; i++) {
        if (states[i] != states[i - 1]) changes++;
      }
      expect(changes, 1);
      expect(states.last, isTrue);
    });

    test('jitter around the release threshold does not flicker', () {
      final l = QiblaLock()..update(1);
      final states = [
        for (final off in [3.9, 4.1, 3.8, 4.05, 3.95, 4.2, 3.7]) l.update(off)
      ];
      var changes = 0;
      var prev = true;
      for (final s in states) {
        if (s != prev) changes++;
        prev = s;
      }
      expect(changes, 1, reason: 'released once, never re-locked at 3.7°');
    });

    test('works with negative differences (turning left)', () {
      final l = QiblaLock()..update(-1.5);
      expect(l.locked, isTrue);
      expect(l.update(-4.5), isFalse);
    });

    test('reset unlocks', () {
      final l = QiblaLock()..update(0);
      l.reset();
      expect(l.locked, isFalse);
    });

    test('thresholds are configurable but exit may not be tighter than enter',
        () {
      expect(() => QiblaLock(enterDegrees: 5, exitDegrees: 2), throwsAssertionError);
      final l = QiblaLock(enterDegrees: 1, exitDegrees: 1.5)..update(1);
      expect(l.update(1.4), isTrue);
      expect(l.update(1.6), isFalse);
    });
  });

  group('CompassAccuracy', () {
    test('maps degrees of error', () {
      expect(CompassAccuracy.fromDegrees(5), CompassAccuracy.excellent);
      expect(CompassAccuracy.fromDegrees(15), CompassAccuracy.excellent);
      expect(CompassAccuracy.fromDegrees(15.1), CompassAccuracy.good);
      expect(CompassAccuracy.fromDegrees(30), CompassAccuracy.good);
      expect(CompassAccuracy.fromDegrees(30.1), CompassAccuracy.poor);
      expect(CompassAccuracy.fromDegrees(45), CompassAccuracy.poor);
    });

    test('unknown when not reported or invalid', () {
      expect(CompassAccuracy.fromDegrees(null), CompassAccuracy.unknown);
      expect(CompassAccuracy.fromDegrees(-1), CompassAccuracy.unknown);
    });
  });
}
