/// The current time for the places that must be testable at a fixed moment (the Home greeting, the
/// notification groups and the demo data behind them). It is the real clock unless a test replaces
/// [now]; production code never does.
abstract final class AppClock {
  static DateTime Function() now = DateTime.now;
}
