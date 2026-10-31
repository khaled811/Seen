import 'package:flutter/services.dart';

/// Blocks screenshots and the app-switcher preview while a sensitive value is visible
/// (Android `FLAG_SECURE`). Other platforms and tests have no handler: that is not an error.
abstract final class SecureScreen {
  static const _channel = MethodChannel('seen_booking/secure_screen');

  static Future<void> set(bool secure) async {
    try {
      await _channel.invokeMethod<void>('set', secure);
    } on MissingPluginException {
      // No native side on this platform.
    } on PlatformException {
      // A failed flag must never break the screen; the value still hides on its own.
    }
  }
}
