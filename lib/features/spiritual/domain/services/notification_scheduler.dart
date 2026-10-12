import '../entities/reminder.dart';

enum NotificationPermission {
  granted,
  denied,

  /// Never asked yet.
  notDetermined,
}

/// Schedules local notifications, abstracted from the plugin.
abstract interface class NotificationScheduler {
  Future<NotificationPermission> permission();

  /// Shows the system permission prompt when it is still undecided.
  Future<NotificationPermission> requestPermission();

  /// Cancels every pending prayer reminder, then schedules [reminders].
  Future<void> replaceAll(List<Reminder> reminders);

  Future<void> cancelAll();
}
