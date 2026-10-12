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
  })  : _getNotificationsUseCase = getNotificationsUseCase,
        _markNotificationReadUseCase = markNotificationReadUseCase,
        _markAllNotificationsReadUseCase = markAllNotificationsReadUseCase,
        super(const NotificationsInitial()) {
    on<NotificationsLoadRequested>(_onLoadRequested, transformer: droppable());
    on<NotificationMarkReadRequested>(_onMarkReadRequested, transformer: droppable());
    on<NotificationsMarkAllReadRequested>(_onMarkAllReadRequested, transformer: droppable());
  }

  final GetNotificationsUseCase _getNotificationsUseCase;
  final MarkNotificationReadUseCase _markNotificationReadUseCase;
  final MarkAllNotificationsReadUseCase _markAllNotificationsReadUseCase;

  Future<void> _onLoadRequested(
    NotificationsLoadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(const NotificationsLoading());
    final result = await _getNotificationsUseCase();
    emit(
      result.match(
        (failure) => NotificationsFailure(failure.message),
        (notifications) => NotificationsLoaded(notifications),
      ),
    );
  }

  Future<void> _onMarkReadRequested(
    NotificationMarkReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    final result = await _markNotificationReadUseCase(event.notificationId);
    final latest = state;
    if (latest is! NotificationsLoaded) return;
    // A boolean read-flag flip is safe to apply locally once the backend
    // confirms it — unlike money, there's no derived figure to get wrong.
    emit(
      result.match(
        (_) => latest, // Failure: leave the feed as-is: a silent retry-later, not worth a snackbar.
        (_) => NotificationsLoaded([
          for (final notification in latest.notifications)
            if (notification.id == event.notificationId)
              notification.copyWith(isRead: true)
            else
              notification,
        ]),
      ),
    );
  }

  Future<void> _onMarkAllReadRequested(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    final result = await _markAllNotificationsReadUseCase();
    final latest = state;
    if (latest is! NotificationsLoaded) return;
    emit(
      result.match(
        (_) => latest,
        (_) => NotificationsLoaded([
          for (final notification in latest.notifications)
            notification.copyWith(isRead: true),
        ]),
      ),
    );
  }
}
