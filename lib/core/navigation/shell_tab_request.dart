import 'package:flutter/foundation.dart';

/// Lets a screen pushed above the agent shell ask it to show a tab after the
/// screen pops (e.g. "Follow request" on the booking receipt → Requests).
/// Tab indexes: 0 home, 1 requests, 2 wallet, 3 sub-agents, 4 account.
///
/// The shell listens, switches tab and resets the value to null. Held as a
/// notifier rather than a route result because the receipt replaces the booking
/// flow and pops to the root.
abstract final class ShellTabRequest {
  static final ValueNotifier<int?> notifier = ValueNotifier<int?>(null);

  static void show(int tab) => notifier.value = tab;
}
