import 'package:equatable/equatable.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the first page (again): on entry, retry and pull-to-refresh.
final class NotificationsLoadRequested extends NotificationsEvent {
  const NotificationsLoadRequested();
}

/// Appends the next page when the list scrolls to its end.
final class NotificationsLoadMoreRequested extends NotificationsEvent {
  const NotificationsLoadMoreRequested();
}

final class NotificationMarkReadRequested extends NotificationsEvent {
  const NotificationMarkReadRequested(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

final class NotificationsMarkAllReadRequested extends NotificationsEvent {
  const NotificationsMarkAllReadRequested();
}

/// The "Unread" chip: the server filters, so the list is loaded again.
final class NotificationsFilterChanged extends NotificationsEvent {
  const NotificationsFilterChanged({required this.unreadOnly});

  final bool unreadOnly;

  @override
  List<Object?> get props => [unreadOnly];
}
