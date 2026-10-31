// The notification inbox against a server that pages, filters and counts like the
// contract: first page, load more, the Unread chip, reading one or all, failures.

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/support/domain/usecases/get_notifications_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/mark_notification_read_usecase.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_bloc.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_event.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_state.dart';
import 'package:seen_booking/features/support/presentation/bloc/unread_notifications_cubit.dart';

import '../../../../support/support_fakes.dart';

NotificationsBloc _bloc(FakeNotificationsRepository repo, {int pageSize = 20}) => NotificationsBloc(
      getNotificationsUseCase: GetNotificationsUseCase(repo),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repo),
      markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(repo),
      pageSize: pageSize,
    );

void main() {
  late FakeNotificationsRepository repo;
  late NotificationsBloc bloc;

  NotificationsLoaded loaded() => bloc.state as NotificationsLoaded;

  Future<void> send(NotificationsEvent event) async {
    bloc.add(event);
    await pumpEventQueue();
  }

  setUp(() {
    repo = FakeNotificationsRepository([
      fakeNotification('1'),
      fakeNotification('2'),
      fakeNotification('3', read: true),
    ]);
    bloc = _bloc(repo);
  });

  tearDown(() => bloc.close());

  test('starts empty', () => expect(bloc.state, const NotificationsInitial()));

  group('loading', () {
    test('the first page, with the server\'s unread total', () async {
      await send(const NotificationsLoadRequested());
      expect(loaded().notifications, hasLength(3));
      expect(loaded().unreadCount, 2);
      expect(loaded().hasMore, isFalse);
      expect(repo.pages.single, (unreadOnly: false, limit: 20, offset: 0));
    });

    test('a failure keeps the failure for the localized text; retry loads', () async {
      repo.failure = const NetworkFailure('off');
      await send(const NotificationsLoadRequested());
      expect((bloc.state as NotificationsFailure).failure, isA<NetworkFailure>());
      repo.failure = null;
      await send(const NotificationsLoadRequested());
      expect(bloc.state, isA<NotificationsLoaded>());
    });

    test('an expired session is a failure like any other (the app routes to sign-in)', () async {
      repo.failure = const UnauthorizedFailure('over', 'session_expired');
      await send(const NotificationsLoadRequested());
      expect((bloc.state as NotificationsFailure).failure, isA<UnauthorizedFailure>());
    });

    test('a reload keeps the chip the person chose', () async {
      await send(const NotificationsLoadRequested());
      await send(const NotificationsFilterChanged(unreadOnly: true));
      await send(const NotificationsLoadRequested());
      expect(loaded().unreadOnly, isTrue);
      expect(repo.pages.last.unreadOnly, isTrue);
    });
  });

  group('paging', () {
    setUp(() {
      repo.items = [for (var i = 0; i < 5; i++) fakeNotification('n$i')];
      bloc = _bloc(repo, pageSize: 2);
    });

    test('more pages are appended once each, in order, until the end', () async {
      await send(const NotificationsLoadRequested());
      expect(loaded().notifications.map((n) => n.id), ['n0', 'n1']);
      expect(loaded().hasMore, isTrue);
      await send(const NotificationsLoadMoreRequested());
      expect(loaded().notifications.map((n) => n.id), ['n0', 'n1', 'n2', 'n3']);
      await send(const NotificationsLoadMoreRequested());
      expect(loaded().notifications, hasLength(5));
      expect(loaded().hasMore, isFalse);
      await send(const NotificationsLoadMoreRequested());
      expect(repo.pages.map((p) => p.offset), [0, 2, 4]); // nothing asked past the end
    });

    test('a new notification that shifts the pages does not show twice', () async {
      await send(const NotificationsLoadRequested());
      repo.items = [fakeNotification('fresh'), ...repo.items];
      await send(const NotificationsLoadMoreRequested());
      expect(loaded().notifications.map((n) => n.id).toSet().length, loaded().notifications.length);
    });

    test('a failed page keeps what is loaded and offers a retry', () async {
      await send(const NotificationsLoadRequested());
      repo.failure = const NetworkFailure('off');
      await send(const NotificationsLoadMoreRequested());
      expect(loaded().notifications, hasLength(2));
      expect(loaded().loadMoreFailed, isTrue);
      expect(loaded().loadingMore, isFalse);
      repo.failure = null;
      await send(const NotificationsLoadMoreRequested());
      expect(loaded().notifications, hasLength(4));
      expect(loaded().loadMoreFailed, isFalse);
    });

    test('a page request while one runs is dropped', () async {
      await send(const NotificationsLoadRequested());
      bloc
        ..add(const NotificationsLoadMoreRequested())
        ..add(const NotificationsLoadMoreRequested());
      await pumpEventQueue();
      expect(repo.pages.where((p) => p.offset == 2), hasLength(1));
    });
  });

  group('the Unread chip (the server filters)', () {
    test('turning it on reloads only the unread ones; turning it off brings all back', () async {
      await send(const NotificationsLoadRequested());
      await send(const NotificationsFilterChanged(unreadOnly: true));
      expect(loaded().unreadOnly, isTrue);
      expect(loaded().visible.map((n) => n.id), ['1', '2']);
      expect(repo.pages.last.unreadOnly, isTrue);
      await send(const NotificationsFilterChanged(unreadOnly: false));
      expect(loaded().visible, hasLength(3));
    });

    test('a failed reload leaves the list and the chip as they were', () async {
      await send(const NotificationsLoadRequested());
      repo.failure = const NetworkFailure('off');
      await send(const NotificationsFilterChanged(unreadOnly: true));
      expect(loaded().unreadOnly, isFalse);
      expect(loaded().filterLoading, isFalse);
      expect(loaded().notifications, hasLength(3));
    });

    test('the same chip again asks nothing', () async {
      await send(const NotificationsLoadRequested());
      await send(const NotificationsFilterChanged(unreadOnly: false));
      expect(repo.pages, hasLength(1));
    });
  });

  group('reading', () {
    test('one notification is read only after the server confirms, and the count follows', () async {
      await send(const NotificationsLoadRequested());
      await send(const NotificationMarkReadRequested('1'));
      expect(loaded().notifications.firstWhere((n) => n.id == '1').isRead, isTrue);
      expect(loaded().notifications.firstWhere((n) => n.id == '2').isRead, isFalse);
      expect(loaded().unreadCount, 1);
      expect(repo.marked, ['1']);
    });

    test('a failure leaves the feed untouched', () async {
      await send(const NotificationsLoadRequested());
      repo.markFailure = const ServerFailure('boom');
      await send(const NotificationMarkReadRequested('1'));
      expect(loaded().notifications.firstWhere((n) => n.id == '1').isRead, isFalse);
      expect(loaded().unreadCount, 2);
    });

    test('a notification the server did not mark (false) stays unread', () async {
      await send(const NotificationsLoadRequested());
      repo.markResult = false;
      await send(const NotificationMarkReadRequested('1'));
      expect(loaded().notifications.firstWhere((n) => n.id == '1').isRead, isFalse);
      expect(loaded().unreadCount, 2);
    });

    test('one that is already read is not sent again; an unknown one is ignored', () async {
      await send(const NotificationsLoadRequested());
      await send(const NotificationMarkReadRequested('3'));
      await send(const NotificationMarkReadRequested('zzz'));
      expect(repo.marked, isEmpty);
    });

    test('the unread count never goes below zero', () async {
      await send(const NotificationsLoadRequested());
      await send(const NotificationMarkReadRequested('1'));
      await send(const NotificationMarkReadRequested('2'));
      expect(loaded().unreadCount, 0);
    });

    test('mark all: every notification is read, whatever the loaded pages', () async {
      await send(const NotificationsLoadRequested());
      await send(const NotificationsMarkAllReadRequested());
      expect(loaded().unreadCount, 0);
      expect(loaded().notifications.every((n) => n.isRead), isTrue);
      expect(repo.markAllCalls, 1);
    });

    test('mark all that fails changes nothing', () async {
      await send(const NotificationsLoadRequested());
      repo.markFailure = const NetworkFailure('off');
      await send(const NotificationsMarkAllReadRequested());
      expect(loaded().unreadCount, 2);
      expect(repo.markAllCalls, 1);
    });

    test('a double tap while it runs sends one call', () async {
      await send(const NotificationsLoadRequested());
      final gate = repo.markAllGate = Completer<void>();
      bloc
        ..add(const NotificationsMarkAllReadRequested())
        ..add(const NotificationsMarkAllReadRequested());
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();
      expect(repo.markAllCalls, 1);
      expect(loaded().unreadCount, 0);
    });
  });

  group('UnreadNotificationsCubit (the badge)', () {
    test('reads the count when it starts and keeps it on a failed poll', () async {
      final cubit = UnreadNotificationsCubit(getCount: GetUnreadNotificationCountUseCase(repo))..start();
      await pumpEventQueue();
      expect(cubit.state, 2);
      repo.unreadCountResult = const Left(NetworkFailure('off'));
      await cubit.refresh();
      expect(cubit.state, 2);
      await cubit.close();
    });

    test('adopts the count the inbox shows, without a call', () async {
      final cubit = UnreadNotificationsCubit(getCount: GetUnreadNotificationCountUseCase(repo));
      cubit.adopt(5);
      expect(cubit.state, 5);
      cubit.adopt(-1);
      expect(cubit.state, 5);
      expect(repo.unreadCountCalls, 0);
      await cubit.close();
    });

    test('polls on its interval, not in the background, and stops when closed', () async {
      final cubit = UnreadNotificationsCubit(
        getCount: GetUnreadNotificationCountUseCase(repo),
        interval: const Duration(milliseconds: 40),
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 130));
      final whileForeground = repo.unreadCountCalls;
      expect(whileForeground, greaterThanOrEqualTo(3)); // the first read and the polls

      cubit.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      final before = repo.unreadCountCalls;
      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(repo.unreadCountCalls, before); // nothing while in the background

      cubit.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(repo.unreadCountCalls, greaterThan(before)); // one read at once on return

      await cubit.close();
      final after = repo.unreadCountCalls;
      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(repo.unreadCountCalls, after);
    });

    test('two reads at once make one call', () async {
      final cubit = UnreadNotificationsCubit(getCount: GetUnreadNotificationCountUseCase(repo));
      await Future.wait([cubit.refresh(), cubit.refresh()]);
      expect(repo.unreadCountCalls, 1);
      await cubit.close();
    });
  });
}
