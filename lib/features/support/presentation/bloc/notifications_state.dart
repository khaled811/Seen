import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
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
  const NotificationsFailure(this.message, {this.failure});

  final String message;

  /// What went wrong, for the user-facing text.
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure];
}

final class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded(
    this.notifications, {
    this.unreadOnly = false,
    this.unreadCount = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.filterLoading = false,
  });

  /// The pages loaded so far (under the current filter), newest first.
  final List<InAppNotification> notifications;

  /// The "Unread" filter chip is on (Figma NOTIF-01).
  final bool unreadOnly;

  /// The unread total of the whole inbox, as the server counts it.
  final int unreadCount;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  /// The list is being reloaded after the chip changed.
  final bool filterLoading;

  /// What the list shows: under the Unread chip a notification read meanwhile
  /// leaves the list at once (the server filtered the page; the rest is local).
  List<InAppNotification> get visible =>
      unreadOnly ? [for (final n in notifications) if (!n.isRead) n] : notifications;

  NotificationsLoaded copyWith({
    List<InAppNotification>? notifications,
    bool? unreadOnly,
    int? unreadCount,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    bool? filterLoading,
  }) =>
      NotificationsLoaded(
        notifications ?? this.notifications,
        unreadOnly: unreadOnly ?? this.unreadOnly,
        unreadCount: unreadCount ?? this.unreadCount,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
        filterLoading: filterLoading ?? this.filterLoading,
      );

  @override
  List<Object?> get props => [notifications, unreadOnly, unreadCount, hasMore, loadingMore, loadMoreFailed, filterLoading];
}
