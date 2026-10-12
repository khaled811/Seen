import 'dart:io' show Platform;

import 'package:flutter_compass/flutter_compass.dart';

import '../../domain/entities/compass_reading.dart';
import '../../domain/services/compass_sensor.dart';

/// [CompassSensor] over `flutter_compass`.
///
/// Android reports magnetic north (the sensor knows nothing about
/// declination); iOS reports true north.
class FlutterCompassSensor implements CompassSensor {
  const FlutterCompassSensor();

  @override
  Stream<CompassReading>? get readings => FlutterCompass.events?.map(
        (e) => CompassReading(heading: e.heading, accuracy: e.accuracy),
      );

  @override
  bool get headingIsMagnetic => Platform.isAndroid;
}
