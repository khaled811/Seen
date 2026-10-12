import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/prayer_id.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/services/notification_scheduler.dart';

/// [NotificationScheduler] over `flutter_local_notifications`.
///
/// Reminders are scheduled as absolute instants (UTC `TZDateTime`), so the
/// device time zone database is not needed. Two Android channels exist because
/// a channel's sound/vibration cannot change once created: one with the
/// system notification sound, one vibrate-only.
///
/// The full adhan recording is not bundled yet, so "sound" uses the system
/// notification sound until an `adhan` raw resource is added.
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const soundChannelId = 'prayer_sound';
  static const vibrateChannelId = 'prayer_vibrate';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;
  bool _asked = false;

  Future<void> _init() async {
    if (_initialised) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested explicitly, never at start-up.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialised = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<NotificationPermission> permission() async {
    await _init();
    final android = _android;
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      if (enabled ?? false) return NotificationPermission.granted;
      // Android 13+ reports "not enabled" both before and after the prompt.
      return _asked ? NotificationPermission.denied : NotificationPermission.notDetermined;
    }
    final ios = _ios;
    if (ios != null) {
      final p = await ios.checkPermissions();
      if (p == null) return NotificationPermission.notDetermined;
      if (p.isEnabled) return NotificationPermission.granted;
      return _asked ? NotificationPermission.denied : NotificationPermission.notDetermined;
    }
    return NotificationPermission.denied; // unsupported platform
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    await _init();
    _asked = true;
    final android = _android;
    if (android != null) {
      final ok = await android.requestNotificationsPermission();
      return (ok ?? false) ? NotificationPermission.granted : NotificationPermission.denied;
    }
    final ios = _ios;
    if (ios != null) {
      final ok = await ios.requestPermissions(alert: true, sound: true);
      return (ok ?? false) ? NotificationPermission.granted : NotificationPermission.denied;
    }
    return NotificationPermission.denied;
  }

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    await _init();
    await _plugin.cancelAll();
    // Exact alarms need a permission the user may not have granted; fall back
    // to inexact (a few minutes late at worst) instead of not reminding.
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        r.id,
        r.title,
        r.body,
        tz.TZDateTime.from(r.time, tz.UTC),
        _details(r),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  NotificationDetails _details(Reminder r) {
    final sound = r.mode == AlertMode.sound;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        sound ? soundChannelId : vibrateChannelId,
        sound ? 'تنبيهات الصلاة (أذان)' : 'تنبيهات الصلاة (اهتزاز)',
        channelDescription: 'تذكير بمواقيت الصلاة',
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(const [0, 400, 200, 400]),
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(presentSound: sound),
    );
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }
}
