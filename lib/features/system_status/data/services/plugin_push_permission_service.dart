import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/push_permission_service.dart';

/// [PushPermissionService] over `flutter_local_notifications` (the permission calls)
/// and `flutter_secure_storage` (what was already asked). It never throws: any
/// platform problem reads as [PushPermissionStatus.unavailable].
class PluginPushPermissionService implements PushPermissionService {
  PluginPushPermissionService({FlutterLocalNotificationsPlugin? plugin, FlutterSecureStorage? storage})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _askedKey = 'push_permission_asked';
  static const _shownKey = 'push_prompt_shown';

  final FlutterLocalNotificationsPlugin _plugin;
  final FlutterSecureStorage _storage;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  Future<bool> _asked() async => (await _storage.read(key: _askedKey)) == 'true';

  @override
  Future<PushPermissionStatus> status() async {
    try {
      final android = _android;
      if (android != null) {
        if (await android.areNotificationsEnabled() ?? false) {
          return PushPermissionStatus.granted;
        }
        // Android 13+ says "not enabled" both before and after the prompt.
        return await _asked() ? PushPermissionStatus.denied : PushPermissionStatus.notDetermined;
      }
      final ios = _ios;
      if (ios != null) {
        final p = await ios.checkPermissions();
        if (p != null && p.isEnabled) {
          return PushPermissionStatus.granted;
        }
        return await _asked() ? PushPermissionStatus.denied : PushPermissionStatus.notDetermined;
      }
    } catch (_) {
      // Fall through: no plugin on this platform or the check failed.
    }
    return PushPermissionStatus.unavailable;
  }

  @override
  Future<PushPermissionStatus> request() async {
    try {
      await _storage.write(key: _askedKey, value: 'true');
      final android = _android;
      if (android != null) {
        final ok = await android.requestNotificationsPermission();
        return (ok ?? false) ? PushPermissionStatus.granted : PushPermissionStatus.denied;
      }
      final ios = _ios;
      if (ios != null) {
        final ok = await ios.requestPermissions(alert: true, badge: true, sound: true);
        return (ok ?? false) ? PushPermissionStatus.granted : PushPermissionStatus.denied;
      }
    } catch (_) {
      // Reads as unavailable below.
    }
    return PushPermissionStatus.unavailable;
  }

  @override
  Future<bool> openSettings() async {
    // `app-settings:` opens the app's settings page on iOS. Android has no such link
    // without a settings plugin, so this answers false there and the screen explains.
    try {
      return await launchUrl(Uri.parse('app-settings:'), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> promptShown() async {
    try {
      return (await _storage.read(key: _shownKey)) == 'true';
    } catch (_) {
      return true; // when in doubt, do not nag
    }
  }

  @override
  Future<void> markPromptShown() async {
    try {
      await _storage.write(key: _shownKey, value: 'true');
    } catch (_) {
      // Worst case the offer shows once more.
    }
  }
}
