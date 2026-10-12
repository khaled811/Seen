/// Hysteresis for the "you are facing the Qibla" state (docs/03 §6).
///
/// Locks when the heading is within ±[enterDegrees] of the Qibla and only
/// releases once it is further than ±[exitDegrees]. Between the two it keeps
/// its previous state, so a noisy heading hovering at the boundary cannot make
/// the lock flicker.
class QiblaLock {
  QiblaLock({this.enterDegrees = 2, this.exitDegrees = 4})
      : assert(exitDegrees >= enterDegrees);

  final double enterDegrees;
  final double exitDegrees;
  bool _locked = false;

  bool get locked => _locked;

  /// [diffDegrees] is the signed shortest angle from the heading to the Qibla.
  /// Returns the new lock state.
  bool update(double diffDegrees) {
    final off = diffDegrees.abs();
    if (_locked) {
      if (off > exitDegrees) _locked = false;
    } else if (off <= enterDegrees) {
      _locked = true;
    }
    return _locked;
  }

  void reset() => _locked = false;
}
