import 'package:equatable/equatable.dart';

/// What the user can switch on or off (Figma NOTIF-04). Each covers one or more event
/// types of the feed; the server decides which pushes belong to which.
enum NotificationCategory { statusUpdates, documents, wallet, subAgents, support, promotions }

/// "Quiet hours": only urgent pushes (e.g. a missed deadline) get through between
/// [startMinutes] and [endMinutes] (minutes after midnight; the end may be earlier than
/// the start, meaning it crosses midnight).
class QuietHours extends Equatable {
  const QuietHours({required this.enabled, required this.startMinutes, required this.endMinutes});

  final bool enabled;
  final int startMinutes;
  final int endMinutes;

  QuietHours copyWith({bool? enabled, int? startMinutes, int? endMinutes}) => QuietHours(
        enabled: enabled ?? this.enabled,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
      );

  @override
  List<Object?> get props => [enabled, startMinutes, endMinutes];
}

class NotificationPreferences extends Equatable {
  const NotificationPreferences({required this.categories, required this.quietHours});

  /// What the design shows before the user changes anything: everything on except
  /// offers and news; quiet hours 23:00 to 07:00.
  static const defaults = NotificationPreferences(
    categories: {
      NotificationCategory.statusUpdates: true,
      NotificationCategory.documents: true,
      NotificationCategory.wallet: true,
      NotificationCategory.subAgents: true,
      NotificationCategory.support: true,
      NotificationCategory.promotions: false,
    },
    quietHours: QuietHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60),
  );

  final Map<NotificationCategory, bool> categories;
  final QuietHours quietHours;

  bool isOn(NotificationCategory c) => categories[c] ?? false;

  NotificationPreferences toggled(NotificationCategory c, bool on) =>
      NotificationPreferences(categories: {...categories, c: on}, quietHours: quietHours);

  NotificationPreferences withQuietHours(QuietHours q) => NotificationPreferences(categories: categories, quietHours: q);

  @override
  List<Object?> get props => [categories, quietHours];
}
