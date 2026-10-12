import 'package:geolocator/geolocator.dart';

import '../../domain/entities/location_fix.dart';
import '../../domain/services/location_service.dart';

/// [LocationService] over `geolocator`. Never throws: every failure maps to a
/// [LocationFix] the caller can degrade from.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({
    this.timeout = const Duration(seconds: 8),
  });

  final Duration timeout;

  @override
  Future<LocationFix> currentFix({required bool askPermission}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServiceDisabled();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return const LocationDenied();
        case LocationPermission.deniedForever:
          return const LocationDeniedForever();
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
      // City-level accuracy is plenty for prayer times and saves battery.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: timeout,
      );
      return LocationFound(position.latitude, position.longitude);
    } catch (_) {
      // Timeout, no signal, or a platform error.
      final last = await _lastKnown();
      return last ?? const LocationUnavailable();
    }
  }

  Future<LocationFound?> _lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : LocationFound(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      // Nothing useful to do if the settings page cannot be opened.
    }
  }
}
