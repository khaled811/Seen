import '../entities/location_fix.dart';
import '../entities/prayer_location.dart';
import '../entities/prayer_preferences.dart';
import '../entities/resolved_location.dart';
import '../repositories/prayer_preferences_repository.dart';
import '../services/location_service.dart';

/// Decides where prayer times are calculated for, degrading gracefully:
///
///  1. a city the user picked by hand;
///  2. a GPS fix (remembered for [freshFor] so the dashboard does not hit the
///     sensor on every open);
///  3. the last remembered fix;
///  4. Makkah.
class ResolveLocationUseCase {
  ResolveLocationUseCase(
    this._service,
    this._preferences, {
    DateTime Function()? clock,
    this.freshFor = const Duration(hours: 6),
  }) : _clock = clock ?? DateTime.now;

  final LocationService _service;
  final PrayerPreferencesRepository _preferences;
  final DateTime Function() _clock;
  final Duration freshFor;

  static const _currentName = 'موقعك الحالي';
  static const _lastKnownName = 'آخر موقع معروف';

  /// [askPermission] may show the system permission dialog; the dashboard
  /// passes false, the prayer screen true. [preferCached] reuses a recent fix
  /// without touching the GPS.
  Future<ResolvedLocation> call({
    required bool askPermission,
    bool preferCached = false,
  }) async {
    final prefs = await _preferences.load();

    final city = SaudiCities.byId(prefs.cityId);
    if (city != null) {
      return ResolvedLocation(city.toLocation(), LocationStatus.manualCity);
    }

    final cached = prefs.lastFix;
    if (preferCached &&
        cached != null &&
        _clock().difference(cached.at) < freshFor) {
      return ResolvedLocation(_fromFix(cached, LocationSource.gps), LocationStatus.gps);
    }

    final fix = await _service.currentFix(askPermission: askPermission);
    if (askPermission && !prefs.locationPrompted) {
      await _preferences.save(prefs.copyWith(locationPrompted: true));
    }

    if (fix is LocationFound) {
      final saved = SavedFix(
        latitude: fix.latitude,
        longitude: fix.longitude,
        at: _clock(),
      );
      // Failing to remember the fix only costs a GPS lookup next time.
      await _preferences.save((await _preferences.load()).copyWith(lastFix: saved));
      return ResolvedLocation(_fromFix(saved, LocationSource.gps), LocationStatus.gps);
    }

    if (cached != null) {
      return ResolvedLocation(
        _fromFix(cached, LocationSource.lastKnown),
        LocationStatus.lastKnown,
      );
    }

    return ResolvedLocation(
      SaudiCities.makkah.toLocation(source: LocationSource.fallback),
      switch (fix) {
        LocationDeniedForever() => LocationStatus.fallbackDeniedForever,
        LocationServiceDisabled() => LocationStatus.fallbackServiceOff,
        LocationUnavailable() => LocationStatus.fallbackUnavailable,
        _ => LocationStatus.fallbackDenied,
      },
    );
  }

  PrayerLocation _fromFix(SavedFix fix, LocationSource source) => PrayerLocation(
        name: source == LocationSource.lastKnown ? _lastKnownName : _currentName,
        latitude: fix.latitude,
        longitude: fix.longitude,
        source: source,
      );
}
