import 'package:equatable/equatable.dart';

import 'location_fix.dart';
import 'prayer_location.dart';

/// The location used for calculation and why.
class ResolvedLocation extends Equatable {
  const ResolvedLocation(this.location, this.status);

  final PrayerLocation location;
  final LocationStatus status;

  /// True when the location is not the user's real position (denied,
  /// unavailable) — the UI offers to fix it.
  bool get isFallback => switch (status) {
        LocationStatus.fallbackDenied ||
        LocationStatus.fallbackDeniedForever ||
        LocationStatus.fallbackServiceOff ||
        LocationStatus.fallbackUnavailable =>
          true,
        _ => false,
      };

  @override
  List<Object?> get props => [location, status];
}
