import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/calc_settings.dart';
import '../../domain/entities/prayer_id.dart';
import '../../domain/entities/prayer_preferences.dart';
import '../../domain/repositories/prayer_preferences_repository.dart';

/// Prayer preferences as one JSON document in `shared_preferences`. Reading is
/// forgiving (unknown or corrupt values fall back to defaults, field by
/// field); every save is awaited by the caller.
class PrayerPreferencesRepositoryImpl implements PrayerPreferencesRepository {
  PrayerPreferencesRepositoryImpl({Future<SharedPreferences>? preferences})
      : _injected = preferences;

  static const storageKey = 'spiritual.prayer_preferences';

  final Future<SharedPreferences>? _injected;

  Future<SharedPreferences> get _prefs =>
      _injected ?? SharedPreferences.getInstance();

  @override
  Future<PrayerPreferences> load() async {
    try {
      final raw = (await _prefs).getString(storageKey);
      if (raw == null) return const PrayerPreferences();
      return _decode(jsonDecode(raw));
    } catch (_) {
      return const PrayerPreferences();
    }
  }

  @override
  Future<Either<Failure, PrayerPreferences>> save(PrayerPreferences p) async {
    try {
      final ok = await (await _prefs).setString(storageKey, jsonEncode(_encode(p)));
      return ok
          ? Right(p)
          : const Left(CacheFailure('Could not save prayer preferences'));
    } catch (e) {
      return Left(CacheFailure('Could not save prayer preferences: $e'));
    }
  }

  static Map<String, Object?> _encode(PrayerPreferences p) => {
        'modes': {for (final e in p.alertModes.entries) e.key.name: e.value.name},
        'method': p.method.name,
        'madhab': p.madhab.name,
        'preAlert': p.preAlertMinutes,
        'city': p.cityId,
        if (p.lastFix != null)
          'fix': {
            'lat': p.lastFix!.latitude,
            'lng': p.lastFix!.longitude,
            'at': p.lastFix!.at.millisecondsSinceEpoch,
          },
        'locationPrompted': p.locationPrompted,
        'notificationsPrompted': p.notificationsPrompted,
      };

  static PrayerPreferences _decode(Object? json) {
    if (json is! Map) return const PrayerPreferences();
    T pick<T>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if ((v as Enum).name == name) return v;
      }
      return fallback;
    }

    final modes = {...PrayerPreferences.defaultModes};
    final rawModes = json['modes'];
    if (rawModes is Map) {
      for (final id in PrayerId.values) {
        modes[id] = pick(AlertMode.values, rawModes[id.name], modes[id]!);
      }
    }
    final pre = json['preAlert'];
    SavedFix? fix;
    final rawFix = json['fix'];
    if (rawFix is Map &&
        rawFix['lat'] is num &&
        rawFix['lng'] is num &&
        rawFix['at'] is int) {
      fix = SavedFix(
        latitude: (rawFix['lat'] as num).toDouble(),
        longitude: (rawFix['lng'] as num).toDouble(),
        at: DateTime.fromMillisecondsSinceEpoch(rawFix['at'] as int),
      );
    }
    return PrayerPreferences(
      alertModes: modes,
      method: pick(CalcMethod.values, json['method'], CalcMethod.ummAlQura),
      madhab: pick(AsrMadhab.values, json['madhab'], AsrMadhab.shafi),
      preAlertMinutes:
          pre is int && PrayerPreferences.preAlertChoices.contains(pre) ? pre : 0,
      cityId: json['city'] is String ? json['city'] as String : null,
      lastFix: fix,
      locationPrompted: json['locationPrompted'] == true,
      notificationsPrompted: json['notificationsPrompted'] == true,
    );
  }
}
