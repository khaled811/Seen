import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/location_fix.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_location.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_preferences.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/resolve_location_usecase.dart';

import '../support/prayer_fakes.dart';

final _now = DateTime(2026, 10, 3, 12);

void main() {
  late FakeLocationService gps;
  late InMemoryPrayerPrefs prefs;

  ResolveLocationUseCase resolver() =>
      ResolveLocationUseCase(gps, prefs, clock: () => _now);

  setUp(() {
    gps = FakeLocationService(const LocationFound(24.7136, 46.6753));
    prefs = InMemoryPrayerPrefs();
  });

  group('GPS available', () {
    test('uses the fix and calls it the current location', () async {
      final r = await resolver()(askPermission: false);
      expect(r.status, LocationStatus.gps);
      expect(r.location.source, LocationSource.gps);
      expect(r.location.name, 'موقعك الحالي');
      expect(r.location.latitude, 24.7136);
      expect(r.isFallback, isFalse);
    });

    test('remembers the fix for later', () async {
      await resolver()(askPermission: false);
      expect(prefs.value.lastFix?.latitude, 24.7136);
      expect(prefs.value.lastFix?.at, _now);
    });

    test('the permission flag is passed through', () async {
      await resolver()(askPermission: true);
      await resolver()(askPermission: false);
      expect(gps.asked, [true, false]);
    });

    test('asking marks the question as already shown', () async {
      expect(prefs.value.locationPrompted, isFalse);
      await resolver()(askPermission: true);
      expect(prefs.value.locationPrompted, isTrue);
    });

    test('not asking does not mark it', () async {
      await resolver()(askPermission: false);
      expect(prefs.value.locationPrompted, isFalse);
    });
  });

  group('manual city wins over everything', () {
    test('GPS is not even consulted', () async {
      prefs.value = const PrayerPreferences(cityId: 'jeddah');
      final r = await resolver()(askPermission: true);
      expect(r.status, LocationStatus.manualCity);
      expect(r.location.name, 'جدة');
      expect(r.location.cityId, 'jeddah');
      expect(gps.asked, isEmpty);
    });

    test('an unknown stored city id falls back to the GPS path', () async {
      prefs.value = const PrayerPreferences(cityId: 'atlantis');
      final r = await resolver()(askPermission: false);
      expect(r.status, LocationStatus.gps);
    });
  });

  group('cached fix', () {
    final fresh = SavedFix(latitude: 26.4, longitude: 50.1, at: _now.subtract(const Duration(hours: 1)));
    final stale = SavedFix(latitude: 26.4, longitude: 50.1, at: _now.subtract(const Duration(hours: 9)));

    test('preferCached reuses a fresh fix without touching the GPS', () async {
      prefs.value = PrayerPreferences(lastFix: fresh);
      final r = await resolver()(askPermission: false, preferCached: true);
      expect(r.status, LocationStatus.gps);
      expect(r.location.latitude, 26.4);
      expect(gps.asked, isEmpty);
    });

    test('a stale fix is refreshed from the GPS', () async {
      prefs.value = PrayerPreferences(lastFix: stale);
      final r = await resolver()(askPermission: false, preferCached: true);
      expect(r.location.latitude, 24.7136);
      expect(gps.asked, [false]);
    });

    test('without preferCached the GPS is always asked', () async {
      prefs.value = PrayerPreferences(lastFix: fresh);
      await resolver()(askPermission: false);
      expect(gps.asked, [false]);
    });
  });

  group('degradation when the GPS cannot help', () {
    final remembered = SavedFix(latitude: 26.4, longitude: 50.1, at: _now.subtract(const Duration(days: 3)));

    for (final (name, fix, expected) in [
      ('permission denied', const LocationDenied(), LocationStatus.fallbackDenied),
      ('permission denied forever', const LocationDeniedForever(), LocationStatus.fallbackDeniedForever),
      ('location services off', const LocationServiceDisabled(), LocationStatus.fallbackServiceOff),
      ('no position (timeout)', const LocationUnavailable(), LocationStatus.fallbackUnavailable),
    ]) {
      test('$name with nothing remembered -> Makkah', () async {
        gps.fix = fix;
        final r = await resolver()(askPermission: true);
        expect(r.status, expected);
        expect(r.isFallback, isTrue);
        expect(r.location.name, 'مكة المكرمة');
        expect(r.location.latitude, 21.4225);
        expect(r.location.longitude, 39.8262);
        expect(r.location.source, LocationSource.fallback);
      });

      test('$name with a remembered fix -> that fix', () async {
        gps.fix = fix;
        prefs.value = PrayerPreferences(lastFix: remembered);
        final r = await resolver()(askPermission: true);
        expect(r.status, LocationStatus.lastKnown);
        expect(r.location.name, 'آخر موقع معروف');
        expect(r.location.latitude, 26.4);
        expect(r.isFallback, isFalse);
      });
    }

    test('a failed denial does not overwrite the remembered fix', () async {
      gps.fix = const LocationDenied();
      prefs.value = PrayerPreferences(lastFix: remembered);
      await resolver()(askPermission: true);
      expect(prefs.value.lastFix, remembered);
    });

    test('a preference store that cannot be written never breaks resolution',
        () async {
      prefs.failSave = true;
      final r = await resolver()(askPermission: true);
      expect(r.status, LocationStatus.gps);
    });
  });
}
