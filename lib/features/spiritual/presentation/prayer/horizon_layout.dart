import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../domain/entities/prayer_day.dart';
import '../../domain/entities/prayer_id.dart';

/// A marker on the daily horizon.
class HorizonMarker extends Equatable {
  const HorizonMarker({
    required this.id,
    required this.x,
    required this.y,
    required this.past,
  });

  final PrayerId id;
  final double x;
  final double y;
  final bool past;

  @override
  List<Object?> get props => [id, x, y, past];
}

/// Geometry of the "daily horizon" card (docs/03 §5) on its 342 × 120 canvas.
///
/// Time flows right to left. A dotted baseline sits at y = 96; the daylight
/// arc is a quadratic curve from sunrise to maghrib peaking at y = 20. The
/// time axis runs from 42 min before fajr to 42 min after midnight and is
/// mapped linearly onto x = 330 … 12.
///
/// Pure maths, no widgets: unit-testable.
class HorizonLayout extends Equatable {
  const HorizonLayout._({
    required this.markers,
    required this.sunriseX,
    required this.maghribX,
    required this.sun,
    required this.elapsedFraction,
  });

  static const width = 342.0;
  static const height = 120.0;
  static const baselineY = 96.0;
  static const apexY = 20.0;
  static const right = 330.0;
  static const left = 12.0;
  static const margin = Duration(minutes: 42);

  /// Control-point height that puts the apex of the quadratic at [apexY].
  static const controlY = 2 * apexY - baselineY; // = -56

  final List<HorizonMarker> markers;
  final double sunriseX;
  final double maghribX;

  /// The sun's position on the arc, or null before sunrise / after maghrib.
  final Offset? sun;

  /// How much of the arc has elapsed: 0 before sunrise, 1 from maghrib on.
  final double elapsedFraction;

  /// [reference] is the moment that splits past from future: the real "now"
  /// when viewing today, the end of the day for past days, the start for
  /// future days.
  factory HorizonLayout.compute(PrayerDay day, DateTime reference) {
    final start = day.fajr.subtract(margin);
    final end = day.midnight.add(margin);
    final span = end.difference(start).inMilliseconds.toDouble();

    double xOf(DateTime t) =>
        right - (t.difference(start).inMilliseconds / span) * (right - left);

    final xs = xOf(day.sunrise);
    final xm = xOf(day.maghrib);
    final xc = (xs + xm) / 2;

    Offset arc(double t) => Offset(
          _quad(xs, xc, xm, t),
          _quad(baselineY, controlY, baselineY, t),
        );

    final markers = <HorizonMarker>[];
    for (final (id, time) in day.entries) {
      final x = xOf(time);
      final onArc = !time.isBefore(day.sunrise) && !time.isAfter(day.maghrib);
      final y = onArc ? arc(((xs - x) / (xs - xm)).clamp(0.0, 1.0)).dy : baselineY;
      markers.add(HorizonMarker(
        id: id,
        x: x,
        y: y,
        past: !time.isAfter(reference),
      ));
    }

    double fraction;
    Offset? sun;
    if (reference.isBefore(day.sunrise)) {
      fraction = 0;
    } else if (!reference.isBefore(day.maghrib)) {
      fraction = 1;
    } else {
      fraction = ((xs - xOf(reference)) / (xs - xm)).clamp(0.0, 1.0);
      sun = arc(fraction);
    }
    return HorizonLayout._(
      markers: markers,
      sunriseX: xs,
      maghribX: xm,
      sun: sun,
      elapsedFraction: fraction,
    );
  }

  double get controlX => (sunriseX + maghribX) / 2;

  /// The part of the daylight arc up to [elapsedFraction], as quadratic
  /// Bézier control points (start, control, end) — de Casteljau split.
  (Offset, Offset, Offset) get elapsedArc {
    final t = elapsedFraction;
    final p0 = Offset(sunriseX, baselineY);
    final p1 = Offset(controlX, controlY);
    final p2 = Offset(maghribX, baselineY);
    final a = Offset.lerp(p0, p1, t)!;
    final b = Offset.lerp(p1, p2, t)!;
    return (p0, a, Offset.lerp(a, b, t)!);
  }

  static double _quad(double p0, double p1, double p2, double t) {
    final u = 1 - t;
    return u * u * p0 + 2 * u * t * p1 + t * t * p2;
  }

  @override
  List<Object?> get props =>
      [markers, sunriseX, maghribX, sun, elapsedFraction];
}
