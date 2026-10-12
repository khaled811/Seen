import 'package:flutter/services.dart';

import '../../domain/services/compass_sensor.dart';

/// Magnetic declination from Android's `GeomagneticField` (World Magnetic
/// Model) through a small method channel (see `MainActivity.kt`). Answers 0
/// where the channel does not exist (iOS reports true north already; tests).
class PlatformDeclinationService implements DeclinationService {
  const PlatformDeclinationService();

  static const channel = MethodChannel('seen_booking/declination');

  @override
  Future<double> declinationDegrees(double latitude, double longitude) async {
    try {
      final value = await channel.invokeMethod<double>(
        'declination',
        {'lat': latitude, 'lng': longitude},
      );
      return value ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }
}
