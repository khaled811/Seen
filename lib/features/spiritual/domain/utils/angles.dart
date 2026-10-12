// Angle helpers (degrees). Compass headings wrap at 360°, so naive
// subtraction or averaging is wrong near north (359° and 1° are 2° apart).

/// [d] wrapped into 0 ≤ d < 360.
double normalizeDegrees(double d) => ((d % 360) + 360) % 360;

/// Signed shortest rotation from [from] to [to], in -180 ≤ delta < 180.
/// Positive means clockwise ("turn right").
double shortestDelta(double from, double to) =>
    (((to - from) % 360) + 540) % 360 - 180;

/// Moves [from] towards [to] by fraction [t] along the shortest arc.
double lerpAngle(double from, double to, double t) =>
    normalizeDegrees(from + shortestDelta(from, to) * t);

/// Exponential low-pass filter for compass headings (docs/04: α = 0.15).
/// Smooths sensor noise without the 359°→1° jump a plain average would make.
class HeadingFilter {
  HeadingFilter({this.alpha = 0.15}) : assert(alpha > 0 && alpha <= 1);

  final double alpha;
  double? _value;

  double? get value => _value;

  /// Feeds a raw heading and returns the filtered one. The first sample is
  /// taken as is.
  double add(double raw) {
    final current = _value;
    return _value = current == null
        ? normalizeDegrees(raw)
        : lerpAngle(current, raw, alpha);
  }

  void reset() => _value = null;
}
