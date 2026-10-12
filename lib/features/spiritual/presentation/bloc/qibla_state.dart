import 'package:equatable/equatable.dart';

import '../../domain/entities/compass_reading.dart';
import '../../domain/entities/resolved_location.dart';
import '../../domain/utils/sun_position.dart';

sealed class QiblaState extends Equatable {
  const QiblaState();

  @override
  List<Object?> get props => [];
}

class QiblaLoading extends QiblaState {
  const QiblaLoading();
}

enum SensorStatus {
  /// Waiting for the first compass sample.
  starting,
  active,

  /// The device has no usable compass: the screen falls back to a static
  /// bearing with a sun/north reference.
  unavailable,
}

class QiblaReady extends QiblaState {
  const QiblaReady({
    required this.resolved,
    required this.bearing,
    required this.distanceKm,
    required this.nearKaaba,
    required this.sensor,
    this.heading,
    this.locked = false,
    this.accuracy = CompassAccuracy.unknown,
    this.lockSeq = 0,
    this.sun,
  });

  final ResolvedLocation resolved;

  /// Qibla bearing from the location, degrees clockwise from true north.
  final double bearing;
  final double distanceKm;

  /// Within 500 m of the Kaaba: the bearing is meaningless.
  final bool nearKaaba;
  final SensorStatus sensor;

  /// Smoothed true heading (0..360), once the compass is active.
  final double? heading;

  /// Facing the Qibla (±2° to lock, ±4° to release).
  final bool locked;
  final CompassAccuracy accuracy;

  /// Increments on every transition into the locked state (haptic trigger).
  final int lockSeq;

  /// The sun, for the no-compass fallback.
  final SunPosition? sun;

  /// Signed shortest turn from the heading to the Qibla (positive = right).
  double? get turn {
    final h = heading;
    if (h == null) return null;
    return (((bearing - h) % 360) + 540) % 360 - 180;
  }

  QiblaReady copyWith({
    ResolvedLocation? resolved,
    double? bearing,
    double? distanceKm,
    bool? nearKaaba,
    SensorStatus? sensor,
    double? heading,
    bool? locked,
    CompassAccuracy? accuracy,
    int? lockSeq,
    SunPosition? sun,
  }) =>
      QiblaReady(
        resolved: resolved ?? this.resolved,
        bearing: bearing ?? this.bearing,
        distanceKm: distanceKm ?? this.distanceKm,
        nearKaaba: nearKaaba ?? this.nearKaaba,
        sensor: sensor ?? this.sensor,
        heading: heading ?? this.heading,
        locked: locked ?? this.locked,
        accuracy: accuracy ?? this.accuracy,
        lockSeq: lockSeq ?? this.lockSeq,
        sun: sun ?? this.sun,
      );

  @override
  List<Object?> get props => [
        resolved,
        bearing,
        distanceKm,
        nearKaaba,
        sensor,
        heading,
        locked,
        accuracy,
        lockSeq,
        sun?.azimuth,
        sun?.altitude,
      ];
}
