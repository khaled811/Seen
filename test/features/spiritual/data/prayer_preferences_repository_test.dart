import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/data/repositories/prayer_preferences_repository_impl.dart';
import 'package:seen_booking/features/spiritual/domain/entities/calc_settings.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_id.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  PrayerPreferencesRepositoryImpl repo() => PrayerPreferencesRepositoryImpl();

  Future<void> storeRaw(Object json) async {
    SharedPreferences.setMockInitialValues({
      PrayerPreferencesRepositoryImpl.storageKey: jsonEncode(json),
    });
  }

  test('nothing stored gives the defaults', () async {
    final p = await repo().load();
    expect(p, const PrayerPreferences());
    expect(p.method, CalcMethod.ummAlQura);
    expect(p.madhab, AsrMadhab.shafi);
    expect(p.preAlertMinutes, 0);
    expect(p.cityId, isNull);
    expect(p.modeOf(PrayerId.fajr), AlertMode.sound);
    expect(p.modeOf(PrayerId.sunrise), AlertMode.silent);
    expect(p.modeOf(PrayerId.midnight), AlertMode.silent);
  });

  test('every field survives a restart', () async {
    final saved = PrayerPreferences(
      // A const map cannot override keys it spreads in.
      // ignore: prefer_const_literals_to_create_immutables
      alertModes: {
        ...PrayerPreferences.defaultModes,
        PrayerId.isha: AlertMode.vibrate,
        PrayerId.sunrise: AlertMode.sound,
      },
      method: CalcMethod.egyptian,
      madhab: AsrMadhab.hanafi,
      preAlertMinutes: 10,
      cityId: 'taif',
      lastFix: SavedFix(
        latitude: 21.27,
        longitude: 40.41,
        at: DateTime(2026, 10, 3, 9, 30),
      ),
      locationPrompted: true,
      notificationsPrompted: true,
    );
    await repo().save(saved);
    // New instance over a fresh handle = a new process.
    final loaded = await PrayerPreferencesRepositoryImpl().load();
    expect(loaded, saved);
    expect(loaded.modeOf(PrayerId.isha), AlertMode.vibrate);
    expect(loaded.lastFix?.at, DateTime(2026, 10, 3, 9, 30));
  });

  test('each save overwrites the previous one', () async {
    final r = repo();
    await r.save(const PrayerPreferences(preAlertMinutes: 5));
    await r.save(const PrayerPreferences(preAlertMinutes: 15));
    expect((await r.load()).preAlertMinutes, 15);
  });

  group('forgiving reads', () {
    test('corrupt JSON gives the defaults', () async {
      SharedPreferences.setMockInitialValues(
        {PrayerPreferencesRepositoryImpl.storageKey: '{oops'},
      );
      expect(await repo().load(), const PrayerPreferences());
    });

    test('a non-object document gives the defaults', () async {
      await storeRaw([1, 2, 3]);
      expect(await repo().load(), const PrayerPreferences());
    });

    test('unknown enum names fall back field by field', () async {
      await storeRaw({
        'method': 'martian',
        'madhab': 'hanafi',
        'modes': {'fajr': 'loud', 'dhuhr': 'vibrate'},
      });
      final p = await repo().load();
      expect(p.method, CalcMethod.ummAlQura, reason: 'unknown -> default');
      expect(p.madhab, AsrMadhab.hanafi, reason: 'valid field kept');
      expect(p.modeOf(PrayerId.fajr), AlertMode.sound, reason: 'unknown -> default');
      expect(p.modeOf(PrayerId.dhuhr), AlertMode.vibrate);
      expect(p.modeOf(PrayerId.asr), AlertMode.sound, reason: 'absent -> default');
    });

    test('an invalid pre-alert value becomes 0', () async {
      for (final bad in [7, -1, 'ten', null, 99]) {
        await storeRaw({'preAlert': bad});
        expect((await repo().load()).preAlertMinutes, 0, reason: '$bad');
      }
    });

    test('valid pre-alert choices are kept', () async {
      for (final ok in PrayerPreferences.preAlertChoices) {
        await storeRaw({'preAlert': ok});
        expect((await repo().load()).preAlertMinutes, ok);
      }
    });

    test('a malformed saved fix is ignored', () async {
      await storeRaw({
        'fix': {'lat': 'x', 'lng': 1, 'at': 5},
      });
      expect((await repo().load()).lastFix, isNull);
    });
  });

  test('the stored document is stable, versionless JSON', () async {
    await repo().save(const PrayerPreferences(cityId: 'riyadh'));
    final prefs = await SharedPreferences.getInstance();
    final json = jsonDecode(
      prefs.getString(PrayerPreferencesRepositoryImpl.storageKey)!,
    ) as Map;
    expect(json['city'], 'riyadh');
    expect(json['method'], 'ummAlQura');
    expect((json['modes'] as Map)['fajr'], 'sound');
  });

  test('storage errors: load falls back, save reports a CacheFailure', () async {
    final failing = PrayerPreferencesRepositoryImpl(
      preferences: Future<SharedPreferences>.delayed(
        const Duration(milliseconds: 1),
        () => throw StateError('no disk'),
      ),
    );
    expect(await failing.load(), const PrayerPreferences());
    final r = await failing.save(const PrayerPreferences());
    expect(r.swap().getOrElse((_) => throw 'x'), isA<CacheFailure>());
  });

  test('value equality ignores map insertion order', () {
    final a = const PrayerPreferences()
        .withMode(PrayerId.asr, AlertMode.silent)
        .withMode(PrayerId.fajr, AlertMode.vibrate);
    final b = const PrayerPreferences()
        .withMode(PrayerId.fajr, AlertMode.vibrate)
        .withMode(PrayerId.asr, AlertMode.silent);
    expect(a, b);
  });

  test('AlertMode cycles sound -> vibrate -> silent -> sound', () {
    expect(AlertMode.sound.next, AlertMode.vibrate);
    expect(AlertMode.vibrate.next, AlertMode.silent);
    expect(AlertMode.silent.next, AlertMode.sound);
  });
}
