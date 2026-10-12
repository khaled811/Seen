import 'dart:math' as math;

import 'angles.dart';

/// Spherical geometry towards the Kaaba.
abstract final class QiblaMath {
  static const kaabaLatitude = 21.4225241;
  static const kaabaLongitude = 39.8261818;

  /// Mean Earth radius, km.
  static const earthRadiusKm = 6371.0088;

  /// Initial great-circle bearing from ([lat], [lng]) to the Kaaba, in
  /// degrees clockwise from true north (0 ≤ b < 360).
  static double bearing(double lat, double lng) {
    final phi1 = _rad(lat);
    final phi2 = _rad(kaabaLatitude);
    final dLng = _rad(kaabaLongitude - lng);
    final y = math.sin(dLng) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    return normalizeDegrees(_deg(math.atan2(y, x)));
  }

  /// Great-circle distance to the Kaaba in km (haversine).
  static double distanceKm(double lat, double lng) {
    final dLat = _rad(kaabaLatitude - lat);
    final dLng = _rad(kaabaLongitude - lng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(kaabaLatitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// Same distance by the spherical law of cosines (used to cross-check the
  /// haversine result).
  static double distanceKmLawOfCosines(double lat, double lng) {
    final phi1 = _rad(lat);
    final phi2 = _rad(kaabaLatitude);
    final c = math.sin(phi1) * math.sin(phi2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.cos(_rad(kaabaLongitude - lng));
    return earthRadiusKm * math.acos(c.clamp(-1.0, 1.0));
  }

  /// Closer than this the bearing is meaningless (you are at the Kaaba).
  static const nearKaabaKm = 0.5;

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
}
