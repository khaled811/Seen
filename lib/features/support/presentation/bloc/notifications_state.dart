import 'package:equatable/equatable.dart';

import '../../domain/entities/in_app_notification.dart';

sealed class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

final class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

final class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

final class NotificationsFailure extends NotificationsState {
  const NotificationsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded(this.notifications, {this.unreadOnly = false});

  final List<InAppNotification> notifications;

  /// The "Unread" filter chip is on (Figma NOTIF-01).
  final bool unreadOnly;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// What the list shows under the current filter.
  List<InAppNotification> get visible => unreadOnly ? [for (final n in notifications) if (!n.isRead) n] : notifications;

  NotificationsLoaded copyWith({List<InAppNotification>? notifications, bool? unreadOnly}) =>
      NotificationsLoaded(notifications ?? this.notifications, unreadOnly: unreadOnly ?? this.unreadOnly);

  @override
  List<Object?> get props => [notifications, unreadOnly];
}
