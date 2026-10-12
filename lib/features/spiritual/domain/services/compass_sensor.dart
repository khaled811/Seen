import '../entities/compass_reading.dart';

/// The device compass, abstracted from the plugin.
abstract interface class CompassSensor {
  /// Live samples, or null when the platform has no compass at all.
  Stream<CompassReading>? get readings;

  /// True when [CompassReading.heading] is relative to *magnetic* north and
  /// must be corrected by the local declination (Android). iOS already
  /// reports true north.
  bool get headingIsMagnetic;
}

/// Angle between magnetic and true north at a place.
abstract interface class DeclinationService {
  /// Degrees east of true north (positive when magnetic north lies east of
  /// it). Returns 0 when unknown.
  Future<double> declinationDegrees(double latitude, double longitude);
}
