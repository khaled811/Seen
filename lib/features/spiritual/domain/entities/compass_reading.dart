import 'package:equatable/equatable.dart';

/// One sample from the device's compass.
class CompassReading extends Equatable {
  const CompassReading({this.heading, this.accuracy});

  /// Degrees clockwise from north (0..360), or null when the device has no
  /// usable compass.
  final double? heading;

  /// Estimated error in degrees (plus/minus), or null when unknown.
  final double? accuracy;

  @override
  List<Object?> get props => [heading, accuracy];
}

/// How trustworthy the compass currently is.
enum CompassAccuracy {
  excellent,
  good,
  poor,
  unknown;

  /// Android reports 15 / 30 / 45 for high / medium / low; iOS reports the
  /// real error in degrees.
  static CompassAccuracy fromDegrees(double? degrees) {
    if (degrees == null || degrees < 0) return unknown;
    if (degrees <= 15) return excellent;
    if (degrees <= 30) return good;
    return poor;
  }
}
