import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_notifications_usecase.dart';
import '../../domain/usecases/mark_all_notifications_read_usecase.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({
    required GetNotificationsUseCase getNotificationsUseCase,
    required MarkNotificationReadUseCase markNotificationReadUseCase,
    required MarkAllNotificationsReadUseCase markAllNotificationsReadUseCase,
    this.pageSize = 20,
  })  : _getNotificationsUseCase = getNotificationsUseCase,
        _markNotificationReadUseCase = markNotificationReadUseCase,
        _markAllNotificationsReadUseCase = markAllNotificationsReadUseCase,
        super(const NotificationsInitial()) {
    // The latest load wins: a chip change supersedes a load in flight.
    on<NotificationsLoadRequested>(_onLoadRequested, transformer: restartable());
    on<NotificationsFilterChanged>(_onFilterChanged, transformer: restartable());
    on<NotificationsLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<NotificationMarkReadRequested>(_onMarkReadRequested, transformer: sequential());
    on<NotificationsMarkAllReadRequested>(_onMarkAllReadRequested, transformer: droppable());
  }

  final GetNotificationsUseCase _getNotificationsUseCase;
  final MarkNotificationReadUseCase _markNotificationReadUseCase;
  final MarkAllNotificationsReadUseCase _markAllNotificationsReadUseCase;

  /// Notifications per page (the contract's default is 30; 20 keeps a page light).
  final int pageSize;

  bool get _unreadOnly {
    final s = state;
    return s is NotificationsLoaded && s.unreadOnly;
  }

  Future<void> _onLoadRequested(NotificationsLoadRequested event, Emitter<NotificationsState> emit) async {
    final unreadOnly = _unreadOnly; // A reload keeps the chip the user chose.
    emit(const NotificationsLoading());
    final result = await _getNotificationsUseCase(unreadOnly: unreadOnly, limit: pageSize);
    emit(
      result.match(
        (failure) => NotificationsFailure(failure.message, failure: failure),
        (page) => NotificationsLoaded(
          page.items,
          unreadOnly: unreadOnly,
          unreadCount: page.unreadCount,
          hasMore: page.hasMore,
        ),
      ),
    );
  }

  Future<void> _onFilterChanged(NotificationsFilterChanged event, Emitter<NotificationsState> emit) async {
    final current = state;
    if (current is! NotificationsLoaded || current.unreadOnly == event.unreadOnly) return;
    emit(current.copyWith(unreadOnly: event.unreadOnly, filterLoading: true, loadMoreFailed: false));
    final result = await _getNotificationsUseCase(unreadOnly: event.unreadOnly, limit: pageSize);
    final latest = state;
    if (latest is! NotificationsLoaded) return;
    emit(
      result.match(
        // The list stays as it was, under the old chip: the chip goes back too.
        (failure) => latest.copyWith(unreadOnly: current.unreadOnly, filterLoading: false),
        (page) => NotificationsLoaded(
          page.items,
          unreadOnly: event.unreadOnly,
          unreadCount: page.unreadCount,
          hasMore: page.hasMore,
        ),
      ),
    );
  }

  Future<void> _onLoadMore(NotificationsLoadMoreRequested event, Emitter<NotificationsState> emit) async {
    final current = state;
    if (current is! NotificationsLoaded || !current.hasMore || current.loadingMore || current.filterLoading) return;
    emit(current.copyWith(loadingMore: true, loadMoreFailed: false));
    final result = await _getNotificationsUseCase(
      unreadOnly: current.unreadOnly,
      limit: pageSize,
      offset: current.notifications.length,
    );
    final latest = state;
    if (latest is! NotificationsLoaded || latest.unreadOnly != current.unreadOnly) return;
    emit(
      result.match(
        (_) => latest.copyWith(loadingMore: false, loadMoreFailed: true),
        (page) {
          // New notifications can shift the pages: keep each id once.
          final known = {for (final n in latest.notifications) n.id};
          return latest.copyWith(
            notifications: [...latest.notifications, for (final n in page.items) if (!known.contains(n.id)) n],
            unreadCount: page.unreadCount,
            hasMore: page.hasMore,
            loadingMore: false,
          );
        },
      ),
    );
  }

  Future<void> _onMarkReadRequested(NotificationMarkReadRequested event, Emitter<NotificationsState> emit) async {
    final current = state;
    if (current is! NotificationsLoaded) return;
    final target = current.notifications.where((n) => n.id == event.notificationId);
    if (target.isEmpty || target.first.isRead) return;

    final result = await _markNotificationReadUseCase(event.notificationId);
    final latest = state;
    if (latest is! NotificationsLoaded) return;
    // A read flag is safe to apply once the server confirms it. A failure leaves
    // the feed as it is: marking is retried the next time it is opened.
    if (result.fold((_) => false, (marked) => marked) == false) return;
    emit(
      latest.copyWith(
        unreadCount: latest.unreadCount > 0 ? latest.unreadCount - 1 : 0,
        notifications: [
          for (final notification in latest.notifications)
            if (notification.id == event.notificationId) notification.copyWith(isRead: true) else notification,
        ],
      ),
    );
  }

  Future<void> _onMarkAllReadRequested(NotificationsMarkAllReadRequested event, Emitter<NotificationsState> emit) async {
    final current = state;
    if (current is! NotificationsLoaded) return;
    final result = await _markAllNotificationsReadUseCase();
    final latest = state;
    if (latest is! NotificationsLoaded) return;
    emit(
      result.match(
        (_) => latest,
        // The server marked every unread one of the inbox, loaded or not.
        (_) => latest.copyWith(
          unreadCount: 0,
          notifications: [for (final notification in latest.notifications) notification.copyWith(isRead: true)],
        ),
      ),
    );
  }
}
