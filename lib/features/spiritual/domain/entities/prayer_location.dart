import 'package:equatable/equatable.dart';

/// Where a location came from.
enum LocationSource { gps, lastKnown, city, fallback }

class PrayerLocation extends Equatable {
  const PrayerLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.cityId,
  });

  /// Arabic display name ("مكة المكرمة", "موقعك الحالي").
  final String name;
  final double latitude;
  final double longitude;
  final LocationSource source;

  /// Set when the location is one of [SaudiCities.all].
  final String? cityId;

  @override
  List<Object?> get props => [name, latitude, longitude, source, cityId];
}

/// A city the user can pick when GPS is unavailable or unwanted.
class SaudiCity extends Equatable {
  const SaudiCity(this.id, this.nameAr, this.latitude, this.longitude);

  final String id;
  final String nameAr;
  final double latitude;
  final double longitude;

  PrayerLocation toLocation({LocationSource source = LocationSource.city}) =>
      PrayerLocation(
        name: nameAr,
        latitude: latitude,
        longitude: longitude,
        source: source,
        cityId: id,
      );

  @override
  List<Object?> get props => [id, nameAr, latitude, longitude];
}

/// Pre-defined cities (approximate city-centre coordinates). Makkah is the
/// default and the final fallback.
abstract final class SaudiCities {
  static const makkah = SaudiCity('makkah', 'مكة المكرمة', 21.4225, 39.8262);

  static const all = <SaudiCity>[
    makkah,
    SaudiCity('madinah', 'المدينة المنورة', 24.4672, 39.6111),
    SaudiCity('riyadh', 'الرياض', 24.7136, 46.6753),
    SaudiCity('jeddah', 'جدة', 21.5433, 39.1728),
    SaudiCity('taif', 'الطائف', 21.2703, 40.4158),
    SaudiCity('dammam', 'الدمام', 26.4207, 50.0888),
    SaudiCity('khobar', 'الخبر', 26.2172, 50.1971),
    SaudiCity('hofuf', 'الهفوف', 25.3647, 49.5876),
    SaudiCity('jubail', 'الجبيل', 27.0046, 49.6460),
    SaudiCity('buraidah', 'بريدة', 26.3260, 43.9750),
    SaudiCity('hail', 'حائل', 27.5114, 41.7208),
    SaudiCity('tabuk', 'تبوك', 28.3838, 36.5550),
    SaudiCity('yanbu', 'ينبع', 24.0895, 38.0618),
    SaudiCity('abha', 'أبها', 18.2164, 42.5053),
    SaudiCity('khamis', 'خميس مشيط', 18.3000, 42.7333),
    SaudiCity('albaha', 'الباحة', 20.0129, 41.4677),
    SaudiCity('jizan', 'جازان', 16.8892, 42.5706),
    SaudiCity('najran', 'نجران', 17.5656, 44.2289),
    SaudiCity('sakaka', 'سكاكا', 29.9697, 40.2064),
    SaudiCity('arar', 'عرعر', 30.9753, 41.0381),
  ];

  static SaudiCity? byId(String? id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}
