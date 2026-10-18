// Support tickets: list (Figma SUP-01), new ticket (SUP-02) and the thread
// (SUP-03), over the real SupportBloc with a fake repository. Arabic / RTL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/foundation/seen_icons.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/support/data/models/support_ticket_dto.dart';
import 'package:seen_booking/features/support/domain/entities/in_app_notification.dart';
import 'package:seen_booking/features/support/domain/entities/support_ticket.dart';
import 'package:seen_booking/features/support/domain/entities/ticket_message.dart';
import 'package:seen_booking/features/support/domain/repositories/support_repository.dart';
import 'package:seen_booking/features/support/domain/repositories/ticket_actions_repository.dart';
import 'package:seen_booking/features/support/domain/usecases/create_ticket_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/get_tickets_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/reply_to_ticket_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/ticket_actions_usecases.dart';
import 'package:seen_booking/features/support/presentation/bloc/support_bloc.dart';
import 'package:seen_booking/features/support/presentation/bloc/support_event.dart';
import 'package:seen_booking/features/support/presentation/bloc/support_state.dart';
import 'package:seen_booking/features/support/presentation/bloc/ticket_actions_cubit.dart';
import 'package:seen_booking/features/support/presentation/screens/create_ticket_screen.dart';
import 'package:seen_booking/features/support/presentation/screens/support_tickets_screen.dart';
import 'package:seen_booking/features/support/presentation/screens/ticket_detail_screen.dart';

// Midday today, so "minutes ago" offsets never cross midnight (the tests used to fail between 00:00 and 01:00).
final _now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 12);

TicketMessage _msg(String id, String body, {bool support = false, String author = 'You', int minutesAgo = 30}) =>
    TicketMessage(
      id: id,
      authorName: author,
      isSupportReply: support,
      body: body,
      sentAt: _now.subtract(Duration(minutes: minutesAgo)),
    );

SupportTicket _ticket(
  String id,
  String subject, {
  SupportTicketStatus status = SupportTicketStatus.open,
  List<TicketMessage>? messages,
  bool unread = false,
}) =>
    SupportTicket(
      id: id,
      referenceId: 'TK-$id',
      category: TicketCategory.general,
      priority: TicketPriority.normal,
      subject: subject,
      status: status,
      createdAt: _now.subtract(const Duration(hours: 1)),
      messages: messages ?? [_msg('$id-1', 'مرحبا')],
      hasUnreadReply: unread,
    );

class _Repo implements SupportRepository {
  _Repo(this.tickets);

  List<SupportTicket> tickets;
  bool failLoad = false;
  bool failReply = false;
  final replies = <String>[];
  TicketPriority? lastPriority;
  String? lastSubject;

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets() async =>
      failLoad ? const Left(NetworkFailure('تعذّر التحميل')) : Right(tickets);

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
  }) async {
    lastPriority = priority;
    lastSubject = subject;
    return Right(_ticket('new', subject, messages: [_msg('new-1', message)]));
  }

  @override
  Future<Either<Failure, SupportTicket>> replyToTicket({required String ticketId, required String message}) async {
    if (failReply) return const Left(NetworkFailure('offline'));
    replies.add(message);
    final t = tickets.firstWhere((t) => t.id == ticketId);
    return Right(t.copyWith(messages: [...t.messages, _msg('r${replies.length}', message, minutesAgo: 0)]));
  }

  @override
  Future<Either<Failure, List<InAppNotification>>> getNotifications() => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> markNotificationRead(String notificationId) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> markAllNotificationsRead() => throw UnimplementedError();
}

class _Actions implements TicketActionsRepository {
  _Actions(this.onReopen);

  final SupportTicket Function(String id) onReopen;
  final read = <String>[];
  final reopened = <String>[];

  @override
  Future<Either<Failure, void>> markRead(String ticketId) async {
    read.add(ticketId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, SupportTicket>> reopen(String ticketId) async {
    reopened.add(ticketId);
    return Right(onReopen(ticketId));
  }
}

SupportBloc _bloc(_Repo repo) => SupportBloc(
      getTicketsUseCase: GetTicketsUseCase(repo),
      createTicketUseCase: CreateTicketUseCase(repo),
      replyToTicketUseCase: ReplyToTicketUseCase(repo),
    );

TicketActionsCubit _actionsCubit(_Actions actions) => TicketActionsCubit(
      markRead: MarkTicketReadUseCase(actions),
      reopen: ReopenTicketUseCase(actions),
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

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('SupportTicket', () {
    test('awaiting the agent: live and support spoke last', () {
      expect(_ticket('1', 'x', messages: [_msg('a', 'q'), _msg('b', 'a', support: true)]).awaitingAgent, true);
      expect(_ticket('1', 'x', messages: [_msg('a', 'q')]).awaitingAgent, false);
      expect(
        _ticket('1', 'x', status: SupportTicketStatus.closed, messages: [_msg('b', 'a', support: true)]).awaitingAgent,
        false,
      );
    });

    test('closed is read-only, resolved is not; activity follows the last message', () {
      expect(_ticket('1', 'x', status: SupportTicketStatus.closed).isClosed, true);
      expect(_ticket('1', 'x', status: SupportTicketStatus.resolved).isClosed, false);
      expect(_ticket('1', 'x', status: SupportTicketStatus.resolved).isLive, false);
      final t = _ticket('1', 'x', messages: [_msg('a', 'q', minutesAgo: 90), _msg('b', 'a', minutesAgo: 5)]);
      expect(t.lastActivityAt, t.messages.last.sentAt);
    });

    test('hasUnreadReply maps from the wire and defaults to false', () {
      Map<String, dynamic> json(Object? unread) => {
            'id': '1',
            'referenceId': 'TK-1',
            'subject': 's',
            'createdAt': '2026-10-14T09:00:00Z',
            'messages': <dynamic>[],
            if (unread != null) 'hasUnreadReply': unread,
          };
      expect(SupportTicketDto.fromJson(json(true)).toEntity().hasUnreadReply, true);
      expect(SupportTicketDto.fromJson(json(null)).toEntity().hasUnreadReply, false);
    });
  });

  group('SupportBloc outbox', () {
    test('a failed send stays in the thread as failed; resending delivers it once', () async {
      final repo = _Repo([_ticket('1', 'x')])..failReply = true;
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      await bloc.stream.firstWhere((s) => s is SupportLoaded);
      bloc.add(const SupportTicketReplySubmitted(ticketId: '1', message: 'مرحبا مجددا'));
      final failed = await bloc.stream.firstWhere(
        (s) => s is SupportLoaded && s.outbox.isNotEmpty && s.outbox.first.status == OutboxStatus.failed,
      ) as SupportLoaded;
      expect(failed.outboxFor('1').single.body, 'مرحبا مجددا');
      expect(failed.replyStatus, ReplyStatus.failure);

      repo.failReply = false;
      bloc.add(SupportOutboxRetryRequested(failed.outbox.single.localId));
      final ok = await bloc.stream.firstWhere((s) => s is SupportLoaded && s.outbox.isEmpty) as SupportLoaded;
      expect(repo.replies, ['مرحبا مجددا']);
      expect(ok.ticketById('1')!.messages.last.body, 'مرحبا مجددا');
      await bloc.close();
    });

    test('messages go out in the order they were typed', () async {
      final repo = _Repo([_ticket('1', 'x')]);
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      await bloc.stream.firstWhere((s) => s is SupportLoaded);
      bloc
        ..add(const SupportTicketReplySubmitted(ticketId: '1', message: 'one'))
        ..add(const SupportTicketReplySubmitted(ticketId: '1', message: 'two'));
      await bloc.stream.firstWhere((s) => s is SupportLoaded && s.replyStatus == ReplyStatus.success && repo.replies.length == 2);
      expect(repo.replies, ['one', 'two']);
      await bloc.close();
    });

    test('retrying something that is not failed does nothing', () async {
      final repo = _Repo([_ticket('1', 'x')]);
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      await bloc.stream.firstWhere((s) => s is SupportLoaded);
      bloc.add(const SupportOutboxRetryRequested('nope'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.replies, isEmpty);
      await bloc.close();
    });

    test('opening marks the ticket read locally; a reopened ticket replaces the old one', () async {
      final repo = _Repo([_ticket('1', 'x', unread: true, status: SupportTicketStatus.closed)]);
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      await bloc.stream.firstWhere((s) => s is SupportLoaded);
      bloc.add(const SupportTicketMarkedRead('1'));
      var s = await bloc.stream.firstWhere((s) => s is SupportLoaded && !s.tickets.first.hasUnreadReply) as SupportLoaded;
      expect(s.tickets.first.hasUnreadReply, false);
      bloc.add(SupportTicketReplaced(_ticket('1', 'x')));
      s = await bloc.stream.firstWhere((s) => s is SupportLoaded && !s.tickets.first.isClosed) as SupportLoaded;
      expect(s.tickets.first.status, SupportTicketStatus.open);
      await bloc.close();
    });

    test('the chosen priority reaches the repository', () async {
      final repo = _Repo([]);
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      await bloc.stream.firstWhere((s) => s is SupportLoaded);
      bloc.add(const SupportTicketCreateSubmitted(
        category: TicketCategory.general,
        subject: 's',
        message: 'm',
        priority: TicketPriority.high,
      ));
      await bloc.stream.firstWhere((s) => s is SupportLoaded && s.createdTicketId != null);
      expect(repo.lastPriority, TicketPriority.high);
      await bloc.close();
    });
  });

  group('SupportTicketsScreen (SUP-01)', () {
    Future<_Repo> open(WidgetTester tester, List<SupportTicket> tickets, {bool failLoad = false}) async {
      final repo = _Repo(tickets)..failLoad = failLoad;
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(SupportTicketsScreen(createBloc: () => _bloc(repo))));
      await settle(tester);
      return repo;
    }

    final tickets = [
      _ticket('1042', 'تأخر إصدار موافقة أمنية', status: SupportTicketStatus.inProgress, unread: true,
          messages: [_msg('a', 'متى؟', minutesAgo: 60), _msg('b', 'قريبا', support: true, minutesAgo: 12)]),
      _ticket('1040', 'تعديل اسم مسافر', messages: [_msg('c', 'q', minutesAgo: 120), _msg('d', 'تفضل', support: true, minutesAgo: 60)]),
      _ticket('1030', 'قديمة', status: SupportTicketStatus.closed),
    ];

    testWidgets('open tab: count, chips, newest first, and the unread reply marker', (tester) async {
      await open(tester, tickets);
      expect(find.text('تذاكر الدعم'), findsOneWidget);
      expect(find.text('مفتوحة · ٢'), findsOneWidget);
      expect(find.text('مغلقة'), findsOneWidget);
      expect(find.text('تأخر إصدار موافقة أمنية'), findsOneWidget);
      expect(find.text('تعديل اسم مسافر'), findsOneWidget);
      expect(find.text('قديمة'), findsNothing);
      // both live tickets have support's reply last: "waiting for you"
      expect(find.text('بانتظار إجراء'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('تأخر إصدار موافقة أمنية')).dy < tester.getTopLeft(find.text('تعديل اسم مسافر')).dy,
        true,
      );
      expect(find.bySemanticsLabel(RegExp('رد جديد')), findsOneWidget);
    });

    testWidgets('the closed tab lists closed tickets', (tester) async {
      await open(tester, tickets);
      await tester.tap(find.text('مغلقة'));
      await tester.pump();
      expect(find.text('قديمة'), findsOneWidget);
      expect(find.text('تعديل اسم مسافر'), findsNothing);
    });

    testWidgets('nothing open says so', (tester) async {
      await open(tester, [tickets.last]);
      expect(find.text('لا تذاكر مفتوحة'), findsOneWidget);
    });

    testWidgets('nothing closed says so', (tester) async {
      await open(tester, [tickets.first]);
      await tester.tap(find.text('مغلقة'));
      await tester.pump();
      expect(find.text('لا تذاكر مغلقة'), findsOneWidget);
    });

    testWidgets('an error shows a retry that loads again', (tester) async {
      final repo = await open(tester, tickets, failLoad: true);
      expect(find.text('تعذّر التحميل'), findsOneWidget);
      repo.failLoad = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.text('تعذّر التحميل'), findsNothing);
      expect(find.text('تعديل اسم مسافر'), findsOneWidget);
    });
  });

  group('CreateTicketScreen (SUP-02)', () {
    Future<_Repo> open(WidgetTester tester) async {
      final repo = _Repo([]);
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BlocProvider.value(value: bloc, child: _app(const CreateTicketScreen())));
      await tester.runAsync(() async {
        while (bloc.state is! SupportLoaded) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      await tester.pump();
      return repo;
    }

    testWidgets('shows the category, priority, subject, description and attachment slot', (tester) async {
      await open(tester);
      for (final label in const ['التصنيف', 'عام', 'تصحيح مالي', 'الأولوية', 'منخفضة', 'عادية', 'عالية', 'الموضوع', 'الوصف', 'إرفاق ملف (اختياري)', 'إرسال التذكرة']) {
        expect(find.textContaining(label), findsWidgets, reason: label);
      }
    });

    testWidgets('an empty subject says it is required and sends nothing', (tester) async {
      final repo = await open(tester);
      await tester.tap(find.text('إرسال التذكرة'));
      await tester.pump();
      expect(find.text('الموضوع مطلوب'), findsOneWidget);
      expect(repo.lastSubject, isNull);
    });

    testWidgets('a filled form sends the chosen priority', (tester) async {
      final repo = await open(tester);
      await tester.tap(find.text('عالية'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(0), 'تأخر الطلب');
      await tester.enterText(find.byType(TextFormField).at(1), 'الطلب SB-1 متأخر');
      await tester.tap(find.text('إرسال التذكرة'));
      await settle(tester);
      expect(repo.lastSubject, 'تأخر الطلب');
      expect(repo.lastPriority, TicketPriority.high);
    });

    testWidgets('the attachment slot says attachments are not available yet', (tester) async {
      await open(tester);
      await tester.tap(find.text('إرفاق ملف (اختياري)'));
      await tester.pump();
      expect(find.text('إرفاق الملفات غير متاح بعد.'), findsOneWidget);
    });
  });

  group('TicketDetailScreen (SUP-03)', () {
    Future<(_Repo, _Actions, SupportBloc)> open(
      WidgetTester tester,
      SupportTicket ticket, {
      bool failReply = false,
    }) async {
      final repo = _Repo([ticket])..failReply = failReply;
      final actions = _Actions((id) => _ticket(id, ticket.subject));
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: _app(TicketDetailScreen(ticketId: ticket.id, createActionsCubit: () => _actionsCubit(actions))),
      ));
      await tester.runAsync(() async {
        while (bloc.state is! SupportLoaded) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      await settle(tester);
      return (repo, actions, bloc);
    }

    final thread = _ticket('1042', 'تأخر إصدار موافقة أمنية', unread: true, messages: [
      _msg('a', 'متى يصدر؟', minutesAgo: 20),
      _msg('b', 'نتوقع الصدور اليوم', support: true, author: 'ريم (عمليات)', minutesAgo: 10),
    ]);

    testWidgets('header, day separator and both sides of the conversation', (tester) async {
      await open(tester, thread);
      expect(find.text('TK-1042'), findsOneWidget);
      expect(find.text('تأخر إصدار موافقة أمنية'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('متى يصدر؟'), findsOneWidget);
      expect(find.text('نتوقع الصدور اليوم'), findsOneWidget);
      expect(find.textContaining('ريم (عمليات)'), findsOneWidget);
      // the agent's bubble starts at the right edge in RTL, support's at the left
      expect(
        tester.getTopRight(find.text('متى يصدر؟')).dx > tester.getTopRight(find.text('نتوقع الصدور اليوم')).dx,
        true,
      );
      expect(find.text('اكتب رسالة...'), findsOneWidget);
    });

    testWidgets('opening an unread thread tells the server it was read', (tester) async {
      final (_, actions, bloc) = await open(tester, thread);
      expect(actions.read, ['1042']);
      expect((bloc.state as SupportLoaded).tickets.first.hasUnreadReply, false);
    });

    testWidgets('a failed send shows the failure and a resend that delivers it', (tester) async {
      final (repo, _, _) = await open(tester, _ticket('7', 'x'), failReply: true);
      await tester.enterText(find.byType(TextField), 'أرفقت صورة الجواز');
      await tester.tap(find.byIcon(SeenIcons.send));
      await settle(tester);
      expect(find.text('أرفقت صورة الجواز'), findsOneWidget);
      expect(find.textContaining('فشل الإرسال'), findsOneWidget);
      repo.failReply = false;
      await tester.tap(find.text('إعادة إرسال'));
      await settle(tester);
      expect(find.text('إعادة إرسال'), findsNothing);
      expect(find.textContaining('فشل الإرسال'), findsNothing);
      expect(repo.replies, ['أرفقت صورة الجواز']);
      expect(find.text('أرفقت صورة الجواز'), findsOneWidget);
    });

    testWidgets('a closed ticket is read-only until it is reopened', (tester) async {
      final closed = _ticket('9', 'مغلقة', status: SupportTicketStatus.closed);
      final (_, actions, _) = await open(tester, closed);
      expect(find.text('عند إغلاق التذكرة تصبح للقراءة فقط'), findsOneWidget);
      expect(find.text('اكتب رسالة...'), findsNothing);
      await tester.tap(find.text('إعادة فتح'));
      await settle(tester);
      expect(actions.reopened, ['9']);
      expect(find.text('عند إغلاق التذكرة تصبح للقراءة فقط'), findsNothing);
      expect(find.text('اكتب رسالة...'), findsOneWidget);
    });

    testWidgets('the attach button says attachments are not available yet', (tester) async {
      await open(tester, _ticket('5', 'x'));
      await tester.tap(find.bySemanticsLabel('إرفاق ملف (اختياري)'));
      await tester.pump();
      expect(find.text('إرفاق الملفات غير متاح بعد.'), findsOneWidget);
    });
  });
}
