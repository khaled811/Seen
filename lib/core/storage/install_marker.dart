import 'package:shared_preferences/shared_preferences.dart';

/// Tells whether this is the first launch since the app was installed.
///
/// The marker lives in `SharedPreferences`, which is removed when the app is
/// uninstalled, unlike the iOS Keychain where secure-storage entries (the
/// refresh cookie) can survive a reinstall. A missing marker therefore means
/// "fresh install: do not trust anything left in the Keychain".
class InstallMarker {
  static const String _key = 'install_marker_v1';

  /// True exactly once per install; marks the install as seen. If the
  /// preferences cannot be read it answers false (never wipe on a broken store,
  /// that would sign the person out on every launch).
  Future<bool> isFirstRunThenMark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key) == true) return false;
      await prefs.setBool(_key, true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
