import 'package:equatable/equatable.dart';

/// Result of asking the device for its position.
sealed class LocationFix extends Equatable {
  const LocationFix();

  @override
  List<Object?> get props => [];
}

class LocationFound extends LocationFix {
  const LocationFound(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}

/// The user said no (can be asked again).
class LocationDenied extends LocationFix {
  const LocationDenied();
}

/// The user said no for good; only system settings can change it.
class LocationDeniedForever extends LocationFix {
  const LocationDeniedForever();
}

/// Location services are switched off on the device.
class LocationServiceDisabled extends LocationFix {
  const LocationServiceDisabled();
}

/// Permission is fine but no position arrived (timeout, no signal).
class LocationUnavailable extends LocationFix {
  const LocationUnavailable();
}

/// Why a location is not the user's real position (for the UI hint).
enum LocationStatus {
  /// A fresh GPS fix.
  gps,

  /// A manually chosen city.
  manualCity,

  /// An earlier GPS fix reused because a new one was not available.
  lastKnown,
  fallbackDenied,
  fallbackDeniedForever,
  fallbackServiceOff,
  fallbackUnavailable,
}
