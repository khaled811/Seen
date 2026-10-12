import 'dart:math' as math;

import 'angles.dart';

/// Where the sun is, for the "no compass" fallback: lets the user find north
/// without a sensor ("the sun is at 230°"). Low-precision NOAA algorithm,
/// good to well under a degree, which is plenty for this purpose.
class SunPosition {
  const SunPosition({required this.azimuth, required this.altitude});

  /// Degrees clockwise from true north.
  final double azimuth;

  /// Degrees above the horizon (negative = below).
  final double altitude;

  bool get isUp => altitude > 0;

  static SunPosition at({
    required double latitude,
    required double longitude,
    required DateTime time,
  }) {
    final utc = time.toUtc();
    // Julian day.
    final jd = utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
    final n = jd - 2451545.0;
    final meanLon = normalizeDegrees(280.460 + 0.9856474 * n);
    final meanAnom = _rad(normalizeDegrees(357.528 + 0.9856003 * n));
    final eclLon = _rad(
      meanLon + 1.915 * math.sin(meanAnom) + 0.020 * math.sin(2 * meanAnom),
    );
    final obliquity = _rad(23.439 - 0.0000004 * n);
    final decl = math.asin(math.sin(obliquity) * math.sin(eclLon));
    final ra = math.atan2(
      math.cos(obliquity) * math.sin(eclLon),
      math.cos(eclLon),
    );
    // Greenwich mean sidereal time -> local hour angle.
    final gmst = normalizeDegrees(280.46061837 + 360.98564736629 * n);
    final lst = _rad(normalizeDegrees(gmst + longitude));
    final hourAngle = lst - ra;
    final lat = _rad(latitude);

    final sinAlt = math.sin(lat) * math.sin(decl) +
        math.cos(lat) * math.cos(decl) * math.cos(hourAngle);
    final alt = math.asin(sinAlt.clamp(-1.0, 1.0));
    final az = math.atan2(
      -math.cos(decl) * math.sin(hourAngle),
      math.sin(decl) * math.cos(lat) -
          math.cos(decl) * math.sin(lat) * math.cos(hourAngle),
    );
    return SunPosition(
      azimuth: normalizeDegrees(_deg(az)),
      altitude: _deg(alt),
    );
  }

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
}
