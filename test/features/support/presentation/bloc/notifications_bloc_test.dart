import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/support/domain/entities/in_app_notification.dart';
import 'package:seen_booking/features/support/domain/entities/support_ticket.dart';
import 'package:seen_booking/features/support/domain/repositories/support_repository.dart';
import 'package:seen_booking/features/support/domain/usecases/get_notifications_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/mark_notification_read_usecase.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_bloc.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_event.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_state.dart';

InAppNotification _notification(String id, {bool isRead = false}) => InAppNotification(
      id: id,
      type: NotificationEventType.statusUpdate,
      title: 'Notification $id',
      body: 'Body $id',
      createdAt: DateTime(2026, 1, 1),
      isRead: isRead,
    );

class _FakeSupportRepository implements SupportRepository {
  Either<Failure, List<InAppNotification>> notificationsResult = Right([
    _notification('1'),
    _notification('2'),
    _notification('3', isRead: true),
  ]);
  Either<Failure, void> markReadResult = const Right(null);
  Either<Failure, void> markAllReadResult = const Right(null);
  int markReadCalls = 0;
  int markAllReadCalls = 0;

  @override
  Future<Either<Failure, List<InAppNotification>>> getNotifications() async =>
      notificationsResult;

  @override
  Future<Either<Failure, void>> markNotificationRead(String notificationId) async {
    markReadCalls++;
    return markReadResult;
  }

  @override
  Future<Either<Failure, void>> markAllNotificationsRead() async {
    markAllReadCalls++;
    return markAllReadResult;
  }

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets() =>
      throw UnimplementedError('Not used by NotificationsBloc');

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
  }) =>
      throw UnimplementedError('Not used by NotificationsBloc');

  @override
  Future<Either<Failure, SupportTicket>> replyToTicket({
    required String ticketId,
    required String message,
  }) =>
      throw UnimplementedError('Not used by NotificationsBloc');
}

void main() {
  late _FakeSupportRepository repository;
  late NotificationsBloc bloc;

  setUp(() {
    repository = _FakeSupportRepository();
    bloc = NotificationsBloc(
      getNotificationsUseCase: GetNotificationsUseCase(repository),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
      markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(repository),
    );
  });

  tearDown(() => bloc.close());

  Future<NotificationsLoaded> load() async {
    bloc.add(const NotificationsLoadRequested());
    return await bloc.stream.firstWhere((s) => s is NotificationsLoaded)
        as NotificationsLoaded;
  }

  test('initial state is NotificationsInitial', () {
    expect(bloc.state, const NotificationsInitial());
  });

  test('NotificationsLoadRequested computes the unread count', () async {
    final state = await load();
    expect(state.notifications, hasLength(3));
    expect(state.unreadCount, 2);
  });

  group('mark as read', () {
    test('flips only the targeted notification to read', () async {
      await load();
      bloc.add(const NotificationMarkReadRequested('1'));
      final state = await bloc.stream.first as NotificationsLoaded;

      expect(state.notifications.firstWhere((n) => n.id == '1').isRead, isTrue);
      expect(state.notifications.firstWhere((n) => n.id == '2').isRead, isFalse);
      expect(state.unreadCount, 1);
      expect(repository.markReadCalls, 1);
    });

    test('leaves the feed untouched on failure', () async {
      await load();
      repository.markReadResult = const Left(ServerFailure('boom'));

      bloc.add(const NotificationMarkReadRequested('1'));
      // No new state is emitted on failure — give the async call a tick,
      // then assert nothing changed.
      await Future<void>.delayed(Duration.zero);
      final state = bloc.state as NotificationsLoaded;
      expect(state.notifications.firstWhere((n) => n.id == '1').isRead, isFalse);
      expect(state.unreadCount, 2);
    });
  });

  group('mark all as read', () {
    test('flips every notification to read', () async {
      await load();
      bloc.add(const NotificationsMarkAllReadRequested());
      final state = await bloc.stream.first as NotificationsLoaded;

      expect(state.unreadCount, 0);
      expect(state.notifications.every((n) => n.isRead), isTrue);
      expect(repository.markAllReadCalls, 1);
    });
  });
}
