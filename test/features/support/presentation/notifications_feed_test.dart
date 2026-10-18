// NOTIF-01 (unread filter + empty), NOTIF-02 (8 event types, deep links), NOTIF-03
// (push permission screen). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/navigation/shell_tab_request.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/support/domain/entities/in_app_notification.dart';
import 'package:seen_booking/features/support/domain/repositories/support_repository.dart';
import 'package:seen_booking/features/support/domain/usecases/get_notifications_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/mark_notification_read_usecase.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_bloc.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_event.dart';
import 'package:seen_booking/features/support/presentation/bloc/notifications_state.dart';
import 'package:seen_booking/features/support/presentation/screens/notifications_screen.dart';
import 'package:seen_booking/features/support/presentation/widgets/notification_kind_mapping.dart';
import 'package:seen_booking/features/system_status/domain/services/push_permission_service.dart';
import 'package:seen_booking/features/system_status/presentation/bloc/push_permission_cubit.dart';
import 'package:seen_booking/features/system_status/presentation/screens/push_permission_screen.dart';

InAppNotification _n(String id, NotificationEventType type,
        {bool read = false, String? request, String? entity, String title = 'عنوان'}) =>
    InAppNotification(
      id: id,
      type: type,
      title: '$title $id',
      body: 'تفصيل',
      createdAt: DateTime.now(),
      isRead: read,
      relatedRequestId: request,
      relatedEntityId: entity,
    );

class _Repo implements SupportRepository {
  _Repo(this.items);
  List<InAppNotification> items;

  @override
  Future<Either<Failure, List<InAppNotification>>> getNotifications() async => Right(items);

  @override
  Future<Either<Failure, void>> markNotificationRead(String notificationId) async => const Right(null);

  @override
  Future<Either<Failure, void>> markAllNotificationsRead() async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

NotificationsBloc _bloc(_Repo repo) => NotificationsBloc(
      getNotificationsUseCase: GetNotificationsUseCase(repo),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repo),
      markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(repo),
    );

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: home,
    );

class _Push implements PushPermissionService {
  _Push(this.current);
  PushPermissionStatus current;
  PushPermissionStatus afterRequest = PushPermissionStatus.granted;
  bool opensSettings = true;
  int requested = 0;
  int settingsOpened = 0;

  @override
  Future<PushPermissionStatus> status() async => current;

  @override
  Future<PushPermissionStatus> request() async {
    requested++;
    current = afterRequest;
    return afterRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return opensSettings;
  }

  @override
  Future<bool> promptShown() async => false;

  @override
  Future<void> markPromptShown() async {}
}

void main() {
  group('event types (NOTIF-02)', () {
    test('every type has its own icon and tone; unknown is neutral', () {
      final kinds = NotificationEventType.values.where((t) => t != NotificationEventType.unknown);
      expect({for (final t in kinds) t.visual.icon}.length, 8);
      expect({for (final t in kinds) t.visual.tone}.length, 8);
    });

    test('where a tap leads, per type', () {
      NotificationTarget? at(NotificationEventType t, {String? request, String? entity}) =>
          notificationTarget(_n('1', t, request: request, entity: entity));
      expect(at(NotificationEventType.newRequest, request: 'SB-1'), NotificationTarget.request);
      expect(at(NotificationEventType.statusUpdate, request: 'SB-1'), NotificationTarget.request);
      expect(at(NotificationEventType.infoRequired, request: 'SB-1'), NotificationTarget.request);
      expect(at(NotificationEventType.rejected, request: 'SB-1'), NotificationTarget.request);
      expect(at(NotificationEventType.slaBreach), NotificationTarget.support);
      expect(at(NotificationEventType.topUp), NotificationTarget.wallet);
      expect(at(NotificationEventType.newAgentSignup), NotificationTarget.agents);
      expect(at(NotificationEventType.ticketUpdate, entity: 'TK-1'), NotificationTarget.ticket);
      expect(at(NotificationEventType.ticketUpdate), NotificationTarget.support);
      // Nothing to open without the id it needs.
      expect(at(NotificationEventType.statusUpdate), isNull);
      expect(at(NotificationEventType.unknown), isNull);
    });
  });

  group('unread filter (NOTIF-01)', () {
    test('the bloc keeps the chip across a reload and after reading', () async {
      final repo = _Repo([_n('1', NotificationEventType.topUp), _n('2', NotificationEventType.topUp, read: true)]);
      final bloc = _bloc(repo)..add(const NotificationsLoadRequested());
      await bloc.stream.firstWhere((s) => s is NotificationsLoaded);
      bloc.add(const NotificationsFilterChanged(unreadOnly: true));
      await bloc.stream.firstWhere((s) => s is NotificationsLoaded && s.unreadOnly);
      expect((bloc.state as NotificationsLoaded).visible.map((n) => n.id), ['1']);
      bloc.add(const NotificationsLoadRequested());
      await bloc.stream.firstWhere((s) => s is NotificationsLoaded);
      expect((bloc.state as NotificationsLoaded).unreadOnly, isTrue);
      bloc.add(const NotificationMarkReadRequested('1'));
      await bloc.stream.firstWhere((s) => s is NotificationsLoaded && s.unreadCount == 0);
      expect((bloc.state as NotificationsLoaded).visible, isEmpty);
      await bloc.close();
    });

    testWidgets('Unread chip shows only unread; when none, the "all caught up" state', (tester) async {
      final repo = _Repo([_n('1', NotificationEventType.topUp, read: true), _n('2', NotificationEventType.topUp, read: true)]);
      final bloc = _bloc(repo)..add(const NotificationsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(BlocProvider.value(value: bloc, child: const NotificationsView())));
      await tester.pump();
      await tester.pump();
      expect(find.text('عنوان 1'), findsOneWidget);
      await tester.tap(find.text('غير المقروءة'));
      await tester.pump();
      expect(find.text('لا إشعارات غير مقروءة'), findsOneWidget);
      expect(find.text('عنوان 1'), findsNothing);
      await tester.tap(find.text('الكل'));
      await tester.pump();
      expect(find.text('عنوان 1'), findsOneWidget);
    });
  });

  group('feed rows (NOTIF-02)', () {
    testWidgets('a navigable row names where it leads; tapping a wallet one asks the shell for the wallet tab', (tester) async {
      final repo = _Repo([_n('1', NotificationEventType.topUp, title: 'شحن الرصيد'), _n('2', NotificationEventType.statusUpdate)]);
      final bloc = _bloc(repo)..add(const NotificationsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(BlocProvider.value(value: bloc, child: const NotificationsView())));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('→ المحفظة'), findsOneWidget);
      // A status update with no request id has nothing to open: no arrow.
      expect(find.textContaining('→ التتبع'), findsNothing);
      await tester.tap(find.text('شحن الرصيد 1'));
      await tester.pump();
      expect(ShellTabRequest.notifier.value, 2);
      ShellTabRequest.notifier.value = null;
    });
  });

  group('push permission (NOTIF-03)', () {
    PushPermissionCubit cubit(_Push svc) => PushPermissionCubit(svc);

    test('first time asks the system; a refusal is remembered as denied', () async {
      final svc = _Push(PushPermissionStatus.notDetermined)..afterRequest = PushPermissionStatus.denied;
      final c = cubit(svc);
      await c.load();
      await c.enable();
      expect(svc.requested, 1);
      expect(c.state.outcome, PushOutcome.refused);
      expect(c.state.status, PushPermissionStatus.denied);
      await c.close();
    });

    test('after a refusal the button opens the settings instead of asking again', () async {
      final svc = _Push(PushPermissionStatus.denied);
      final c = cubit(svc);
      await c.load();
      await c.enable();
      expect(svc.requested, 0);
      expect(svc.settingsOpened, 1);
      expect(c.state.outcome, PushOutcome.openedSettings);
      svc.opensSettings = false;
      await c.enable();
      expect(c.state.outcome, PushOutcome.settingsUnavailable);
      await c.close();
    });

    testWidgets('screen: copy, examples, enable grants and leaves; later leaves', (tester) async {
      final svc = _Push(PushPermissionStatus.notDetermined);
      bool? result;
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => PushPermissionScreen(createCubit: () => cubit(svc))),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('لا تفوّت أي تحديث'), findsOneWidget);
      expect(find.text('صدرت تأشيرة عميلك'), findsOneWidget);
      expect(find.textContaining('يتبقى'), findsOneWidget);
      expect(find.textContaining('رفضت الإذن'), findsNothing);
      await tester.tap(find.text('تفعيل الإشعارات'));
      await tester.pumpAndSettle();
      expect(svc.requested, 1);
      expect(result, isTrue);
      expect(find.text('الإشعارات مفعّلة.'), findsOneWidget);
    });

    testWidgets('screen: refused before shows the settings banner; Later returns false', (tester) async {
      final svc = _Push(PushPermissionStatus.denied);
      bool? result;
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => PushPermissionScreen(createCubit: () => cubit(svc))),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('رفضت الإذن سابقًا'), findsOneWidget);
      await tester.tap(find.text('الإعدادات'));
      await tester.pump();
      expect(svc.settingsOpened, 1);
      await tester.tap(find.text('لاحقًا'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
