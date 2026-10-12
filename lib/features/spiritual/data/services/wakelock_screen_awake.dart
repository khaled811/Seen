import 'package:wakelock_plus/wakelock_plus.dart';

import '../../domain/services/screen_awake.dart';

/// [ScreenAwake] backed by `wakelock_plus`. A failure to toggle the wakelock
/// (unsupported platform, plugin missing) must never break the screen, so
/// errors are swallowed here deliberately: the worst case is the display
/// dimming on its normal timeout.
class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> hold() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  @override
  Future<void> release() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
