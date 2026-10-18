import 'package:equatable/equatable.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

final class NotificationsLoadRequested extends NotificationsEvent {
  const NotificationsLoadRequested();
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

final class NotificationsFilterChanged extends NotificationsEvent {
  const NotificationsFilterChanged({required this.unreadOnly});

  final bool unreadOnly;

  @override
  List<Object?> get props => [unreadOnly];
}
