import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/compass_reading.dart';
import 'package:seen_booking/features/spiritual/domain/entities/location_fix.dart';
import 'package:seen_booking/features/spiritual/domain/utils/angles.dart';
import 'package:seen_booking/features/spiritual/domain/utils/qibla_math.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/qibla_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/qibla_state.dart';

import '../support/prayer_fakes.dart';

const _riyadh = LocationFound(24.7136, 46.6753);
final _riyadhBearing = QiblaMath.bearing(24.7136, 46.6753); // ≈ 244.6

Future<void> _settle([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

Future<QiblaCubit> _started(
  PrayerHarness h, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final cubit = QiblaCubit(h.module, sensorTimeout: timeout);
  await cubit.start();
  return cubit;
}

QiblaReady _s(QiblaCubit c) => c.state as QiblaReady;

/// Feeds [raw] repeatedly so the 0.15 low-pass filter settles on it.
Future<void> _feed(PrayerHarness h, double raw, {int times = 60, double? acc = 15}) async {
  for (var i = 0; i < times; i++) {
    h.compass.emit(raw, accuracy: acc);
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('location and geometry', () {
    test('resolves the location and computes bearing and distance', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      final s = _s(cubit);
      expect(s.resolved.location.name, 'موقعك الحالي');
      expect(s.bearing, closeTo(_riyadhBearing, 1e-9));
      expect(s.distanceKm, closeTo(790, 10));
      expect(s.nearKaaba, isFalse);
      expect(s.sensor, SensorStatus.starting);
      expect(s.heading, isNull);
      expect(s.sun, isNotNull);
      await cubit.close();
      await h.compass.dispose();
    });

    test('the first visit asks for location permission, later ones do not',
        () async {
      final h = PrayerHarness(fix: _riyadh);
      var cubit = await _started(h);
      expect(h.location.asked, [true]);
      await cubit.close();
      cubit = await _started(h);
      expect(h.location.asked, [true], reason: 'fresh fix reused, GPS not queried');
      await cubit.close();
      await h.compass.dispose();
    });

    test('location denied: falls back to Makkah, which is next to the Kaaba',
        () async {
      final h = PrayerHarness(fix: const LocationDenied());
      final cubit = await _started(h);
      final s = _s(cubit);
      expect(s.resolved.isFallback, isTrue);
      expect(s.resolved.location.name, 'مكة المكرمة');
      expect(s.nearKaaba, isTrue);
      await cubit.close();
      await h.compass.dispose();
    });

    test('a chosen city changes the bearing and distance', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      await cubit.relocate(cityId: 'jeddah');
      final s = _s(cubit);
      expect(s.resolved.location.name, 'جدة');
      expect(s.bearing, closeTo(101, 2));
      expect(s.distanceKm, closeTo(70, 10));
      expect((await h.prefs.load()).cityId, 'jeddah');
      await cubit.close();
      await h.compass.dispose();
    });

    test('"use GPS" clears the city and asks again', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      await cubit.relocate(cityId: 'jeddah');
      await cubit.relocate(useGps: true);
      expect(_s(cubit).resolved.location.name, 'موقعك الحالي');
      expect((await h.prefs.load()).cityId, isNull);
      expect(h.location.asked.last, isTrue);
      await cubit.close();
      await h.compass.dispose();
    });
  });

  group('sensor availability', () {
    test('no compass stream at all -> unavailable (no crash)', () async {
      final h = PrayerHarness(
        fix: _riyadh,
        compass: FakeCompassSensor(available: false),
      );
      final cubit = await _started(h);
      expect(_s(cubit).sensor, SensorStatus.unavailable);
      expect(_s(cubit).heading, isNull);
      expect(_s(cubit).locked, isFalse);
      await cubit.close();
    });

    test('a null heading means no magnetometer -> unavailable', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(null);
      await _settle();
      expect(_s(cubit).sensor, SensorStatus.unavailable);
      await cubit.close();
      await h.compass.dispose();
    });

    test('silence for the timeout -> unavailable', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h, timeout: const Duration(milliseconds: 40));
      expect(_s(cubit).sensor, SensorStatus.starting);
      await _settle(90);
      expect(_s(cubit).sensor, SensorStatus.unavailable);
      await cubit.close();
      await h.compass.dispose();
    });

    test('a sensor that does answer is never declared unavailable by the timer',
        () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h, timeout: const Duration(milliseconds: 40));
      h.compass.emit(100);
      await _settle(90);
      expect(_s(cubit).sensor, SensorStatus.active);
      await cubit.close();
      await h.compass.dispose();
    });

    test('a stream error -> unavailable', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.fail();
      await _settle();
      expect(_s(cubit).sensor, SensorStatus.unavailable);
      await cubit.close();
      await h.compass.dispose();
    });

    test('the static bearing is still available when the sensor is not',
        () async {
      final h = PrayerHarness(fix: _riyadh, compass: FakeCompassSensor(available: false));
      final cubit = await _started(h);
      expect(_s(cubit).bearing, closeTo(_riyadhBearing, 1e-9));
      expect(_s(cubit).distanceKm, greaterThan(0));
      await cubit.close();
    });

    test('a null heading AFTER good samples is ignored, not fatal', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(100);
      await _settle();
      h.compass.emit(null);
      await _settle();
      expect(_s(cubit).sensor, SensorStatus.active);
      await cubit.close();
      await h.compass.dispose();
    });
  });

  group('heading', () {
    test('the first sample is taken as is, later ones are low-pass filtered',
        () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(100);
      await _settle();
      expect(_s(cubit).heading, 100);
      h.compass.emit(200);
      await _settle();
      expect(_s(cubit).heading, closeTo(115, 1e-6));
      await cubit.close();
      await h.compass.dispose();
    });

    test('noise around north never swings the heading through 180°', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(0);
      await _settle();
      final seen = <double>[];
      for (var i = 0; i < 30; i++) {
        h.compass.emit(i.isEven ? 358 : 2);
        await Future<void>.delayed(Duration.zero);
        seen.add(_s(cubit).heading!);
      }
      for (final v in seen) {
        expect(shortestDelta(0, v).abs(), lessThan(6));
      }
      await cubit.close();
      await h.compass.dispose();
    });

    test('changes smaller than 0.2° are not emitted (no rebuild storm)',
        () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(100);
      await _settle();
      final emitted = <QiblaState>[];
      final sub = cubit.stream.listen(emitted.add);
      for (var i = 0; i < 20; i++) {
        h.compass.emit(100.1 + (i.isEven ? 0.05 : -0.05));
        await Future<void>.delayed(Duration.zero);
      }
      expect(emitted, isEmpty);
      await sub.cancel();
      await cubit.close();
      await h.compass.dispose();
    });

    test('the turn is the signed shortest angle to the Qibla', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(_riyadhBearing - 30);
      await _settle();
      expect(_s(cubit).turn, closeTo(30, 1e-6), reason: 'turn right');
      await cubit.close();
      await h.compass.dispose();
    });
  });

  group('magnetic declination', () {
    test('Android-style (magnetic) headings are corrected to true north',
        () async {
      final decl = FakeDeclination(4.5);
      final h = PrayerHarness(
        fix: _riyadh,
        compass: FakeCompassSensor(magnetic: true),
        declination: decl,
      );
      final cubit = await _started(h);
      expect(decl.asked, [(24.7136, 46.6753)]);
      h.compass.emit(240);
      await _settle();
      expect(_s(cubit).heading, closeTo(244.5, 1e-6));
      await cubit.close();
      await h.compass.dispose();
    });

    test('a negative declination and wrap-around', () async {
      final h = PrayerHarness(
        fix: _riyadh,
        compass: FakeCompassSensor(magnetic: true),
        declination: FakeDeclination(-5),
      );
      final cubit = await _started(h);
      h.compass.emit(3);
      await _settle();
      expect(_s(cubit).heading, closeTo(358, 1e-6));
      await cubit.close();
      await h.compass.dispose();
    });

    test('iOS-style (true north) headings are used as they are', () async {
      final decl = FakeDeclination(4.5);
      final h = PrayerHarness(fix: _riyadh, declination: decl);
      final cubit = await _started(h);
      expect(decl.asked, isEmpty, reason: 'not even asked');
      h.compass.emit(240);
      await _settle();
      expect(_s(cubit).heading, 240);
      await cubit.close();
      await h.compass.dispose();
    });

    test('a failing declination lookup degrades to 0, the compass still works',
        () async {
      final h = PrayerHarness(
        fix: _riyadh,
        compass: FakeCompassSensor(magnetic: true),
        declination: FakeDeclination(4.5, true),
      );
      final cubit = await _started(h);
      h.compass.emit(240);
      await _settle();
      expect(_s(cubit).heading, 240);
      await cubit.close();
      await h.compass.dispose();
    });
  });

  group('lock hysteresis through the cubit', () {
    test('locks once the filtered heading is within ±2° of the Qibla', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(_riyadhBearing + 10);
      await _settle();
      expect(_s(cubit).locked, isFalse);
      await _feed(h, _riyadhBearing, times: 40);
      expect(_s(cubit).locked, isTrue);
      expect(_s(cubit).lockSeq, 1);
      await cubit.close();
      await h.compass.dispose();
    });

    test('never locks while the heading stays 3° away', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      await _feed(h, _riyadhBearing + 3, times: 30);
      expect(_s(cubit).locked, isFalse);
      expect(_s(cubit).lockSeq, 0);
      await cubit.close();
      await h.compass.dispose();
    });

    test('once locked it survives 3° of wobble (no flicker)', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      await _feed(h, _riyadhBearing);
      expect(_s(cubit).locked, isTrue);
      final locks = <bool>[];
      for (var i = 0; i < 20; i++) {
        h.compass.emit(_riyadhBearing + (i.isEven ? 3 : -3));
        await Future<void>.delayed(Duration.zero);
        locks.add(_s(cubit).locked);
      }
      expect(locks.every((l) => l), isTrue);
      expect(_s(cubit).lockSeq, 1, reason: 'the haptic trigger fired once');
      await cubit.close();
      await h.compass.dispose();
    });

    test('releases beyond ±4°, and does not re-lock at 3°', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      await _feed(h, _riyadhBearing);
      expect(_s(cubit).locked, isTrue);
      await _feed(h, _riyadhBearing + 8);
      expect(_s(cubit).locked, isFalse);
      await _feed(h, _riyadhBearing + 3, times: 40);
      expect(_s(cubit).locked, isFalse, reason: '3° is inside the dead band');
      expect(_s(cubit).lockSeq, 1);
      await cubit.close();
      await h.compass.dispose();
    });

    test('each fresh lock bumps lockSeq (one haptic per lock)', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      await _feed(h, _riyadhBearing);
      await _feed(h, _riyadhBearing + 40);
      await _feed(h, _riyadhBearing);
      expect(_s(cubit).locked, isTrue);
      expect(_s(cubit).lockSeq, 2);
      await cubit.close();
      await h.compass.dispose();
    });

    test('locking works across north (Qibla at 359°, heading at 1°)', () async {
      // A place whose Qibla is just west of north: due south of the Kaaba.
      final h = PrayerHarness(fix: const LocationFound(2, 39.8262));
      final cubit = await _started(h);
      final bearing = _s(cubit).bearing; // ≈ 0°
      expect(shortestDelta(bearing, 0).abs(), lessThan(1));
      await _feed(h, normalizeDegrees(bearing - 358.5)); // ~1.5° off, wrapped
      await _feed(h, normalizeDegrees(bearing + 1));
      expect(_s(cubit).locked, isTrue);
      await cubit.close();
      await h.compass.dispose();
    });

    test('beside the Kaaba there is nothing to lock onto', () async {
      final h = PrayerHarness(fix: const LocationFound(21.4225, 39.8262));
      final cubit = await _started(h);
      expect(_s(cubit).nearKaaba, isTrue);
      await _feed(h, 123);
      expect(_s(cubit).locked, isFalse);
      expect(_s(cubit).lockSeq, 0);
      await cubit.close();
      await h.compass.dispose();
    });

    test('a city change resets the lock', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      await _feed(h, _riyadhBearing);
      expect(_s(cubit).locked, isTrue);
      await cubit.relocate(cityId: 'tabuk');
      expect(_s(cubit).locked, isFalse);
      await cubit.close();
      await h.compass.dispose();
    });
  });

  group('calibration accuracy', () {
    test('maps the sensor\'s error to excellent / good / poor', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(100, accuracy: 10);
      await _settle();
      expect(_s(cubit).accuracy, CompassAccuracy.excellent);
      h.compass.emit(100, accuracy: 30);
      await _settle();
      expect(_s(cubit).accuracy, CompassAccuracy.good);
      h.compass.emit(100, accuracy: 45);
      await _settle();
      expect(_s(cubit).accuracy, CompassAccuracy.poor);
      h.compass.emit(100, accuracy: null);
      await _settle();
      expect(_s(cubit).accuracy, CompassAccuracy.unknown);
      await cubit.close();
      await h.compass.dispose();
    });

    test('a change in accuracy alone is emitted (banner appears)', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(100, accuracy: 15);
      await _settle();
      final emitted = <QiblaState>[];
      final sub = cubit.stream.listen(emitted.add);
      h.compass.emit(100, accuracy: 45); // same heading
      await _settle();
      expect(emitted, hasLength(1));
      await sub.cancel();
      await cubit.close();
      await h.compass.dispose();
    });
  });

  group('lifecycle', () {
    test('pausing detaches from the sensor; resuming re-attaches cleanly',
        () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      h.compass.emit(100);
      await _settle();
      expect(h.compass.listeners, 1);

      cubit.setActive(false);
      await _settle();
      expect(h.compass.listeners, 0, reason: 'no sensor use in the background');
      h.compass.emit(200);
      await _settle();
      expect(_s(cubit).heading, 100, reason: 'ignored while paused');

      cubit.setActive(true);
      await _settle();
      expect(h.compass.listeners, 1);
      h.compass.emit(300);
      await _settle();
      expect(_s(cubit).heading, 300, reason: 'filter restarted: first sample exact');
      await cubit.close();
      await h.compass.dispose();
    });

    test('resuming does not leave a stale lock', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h);
      await _feed(h, _riyadhBearing);
      expect(_s(cubit).locked, isTrue);
      cubit.setActive(false);
      cubit.setActive(true);
      h.compass.emit(_riyadhBearing + 90);
      await _settle();
      expect(_s(cubit).locked, isFalse);
      await cubit.close();
      await h.compass.dispose();
    });

    test('closing cancels the subscription and the timer', () async {
      final h = PrayerHarness(fix: _riyadh);
      final cubit = await _started(h, timeout: const Duration(milliseconds: 40));
      await cubit.close();
      expect(h.compass.listeners, 0);
      await _settle(90); // the timeout would have fired; must not throw
      await h.compass.dispose();
    });

    test('an unavailable sensor stays unavailable across pause/resume',
        () async {
      final h = PrayerHarness(fix: _riyadh, compass: FakeCompassSensor(available: false));
      final cubit = await _started(h);
      cubit.setActive(false);
      cubit.setActive(true);
      expect(_s(cubit).sensor, SensorStatus.unavailable);
      await cubit.close();
    });
  });
}
