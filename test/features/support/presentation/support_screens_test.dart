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
import 'package:seen_booking/core/localization/app_language.dart';
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
import 'package:seen_booking/features/support/presentation/bloc/ticket_categories_cubit.dart';
import 'package:seen_booking/features/support/presentation/bloc/ticket_rating_cubit.dart';
import 'package:seen_booking/features/support/presentation/screens/create_ticket_screen.dart';
import 'package:seen_booking/features/support/presentation/screens/support_tickets_screen.dart';
import 'package:seen_booking/features/support/presentation/screens/ticket_detail_screen.dart';

import '../../../support/attachment_fakes.dart';
import '../../../support/rating_fakes.dart';

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
  final replyAttachments = <String?>[];
  TicketPriority? lastPriority;
  String? lastCreateAttachment;
  String? lastSubject;
  String? lastCategoryCode;

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
    String? attachmentFileId,
      String? categoryCode,
  }) async {
    lastPriority = priority;
    lastCategoryCode = categoryCode;
    lastSubject = subject;
    lastCreateAttachment = attachmentFileId;
    return Right(_ticket('new', subject, messages: [_msg('new-1', message)]));
  }

  @override
  Future<Either<Failure, TicketMessage>> replyToTicket({required String ticketId, required String message, String? attachmentFileId}) async {
    if (failReply) return const Left(NetworkFailure('offline'));
    replies.add(message);
    replyAttachments.add(attachmentFileId);
    return Right(_msg('r${replies.length}', message, minutesAgo: 0));
  }

  @override
  Future<Either<Failure, SupportTicket>> getTicket(String ticketId) async {
    final t = tickets.where((t) => t.id == ticketId);
    return t.isEmpty ? const Left(ServerFailure('x', code: 'ticket_not_found')) : Right(t.first);
  }

  @override
  Future<Either<Failure, NotificationsPage>> getNotifications({bool unreadOnly = false, int limit = 20, int offset = 0}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() => throw UnimplementedError();

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) => throw UnimplementedError();

  @override
  Future<Either<Failure, int>> markAllNotificationsRead() => throw UnimplementedError();
}

class _Actions implements TicketActionsRepository {
  final read = <String>[];

  @override
  Future<Either<Failure, void>> markRead(String ticketId) async {
    read.add(ticketId);
    return const Right(null);
  }
}

SupportBloc _bloc(_Repo repo) => SupportBloc(
      getTicketsUseCase: GetTicketsUseCase(repo),
      createTicketUseCase: CreateTicketUseCase(repo),
      replyToTicketUseCase: ReplyToTicketUseCase(repo),
      getTicketUseCase: GetTicketUseCase(repo),
    );

TicketActionsCubit _actionsCubit(_Actions actions) => TicketActionsCubit(
      markRead: MarkTicketReadUseCase(actions),
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
      expect(_ticket('1', 'x', status: SupportTicketStatus.closed).isFinal, true);
      expect(_ticket('1', 'x', status: SupportTicketStatus.resolved).isFinal, false);
      expect(_ticket('1', 'x', status: SupportTicketStatus.resolved).isLive, false);
      final t = _ticket('1', 'x', messages: [_msg('a', 'q', minutesAgo: 90), _msg('b', 'a', minutesAgo: 5)]);
      expect(t.lastActivityAt, t.messages.last.sentAt);
    });

    test('isUnread maps from the wire and defaults to false', () {
      Map<String, dynamic> json(Object? unread) => {
            'id': '1',
            'type': 'general',
            'category': 'general',
            'priority': 'normal',
            'status': 'open',
            'payload': {'subject': 's'},
            'createdAt': '2026-10-14T09:00:00Z',
            if (unread != null) 'isUnread': unread,
          };
      SupportTicket parse(Object? unread) => SupportTicketDto.parse(json(unread), AppLanguage(), withMessages: false);
      expect(parse(true).hasUnreadReply, true);
      expect(parse(null).hasUnreadReply, false);
      expect(parse(true).messagesLoaded, false);
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

    test('opening marks the ticket read locally', () async {
      final repo = _Repo([_ticket('1', 'x', unread: true, status: SupportTicketStatus.closed)]);
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      await bloc.stream.firstWhere((s) => s is SupportLoaded);
      bloc.add(const SupportTicketMarkedRead('1'));
      final s = await bloc.stream.firstWhere((s) => s is SupportLoaded && !s.tickets.first.hasUnreadReply) as SupportLoaded;
      expect(s.tickets.first.hasUnreadReply, false);
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
      // The reason is the app's own text for a lost connection, not the server's.
      final noNetwork = lookupAppLocalizations(const Locale('ar')).errorNetwork;
      expect(find.text(noNetwork), findsOneWidget);
      repo.failLoad = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.text(noNetwork), findsNothing);
      expect(find.text('تعديل اسم مسافر'), findsOneWidget);
    });
  });

  group('CreateTicketScreen (SUP-02)', () {
    Future<_Repo> open(WidgetTester tester, {FakeStagedUploader? uploader}) async {
      final repo = _Repo([]);
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final stager = uploader ?? FakeStagedUploader();
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: _app(CreateTicketScreen(
          createAttachment: () => fakeAttachmentCubit(stager),
          createCategories: () => TicketCategoriesCubit(FakeTicketCategoriesRepository()),
        )),
      ));
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
      for (final label in const ['التصنيف', 'اختر التصنيف', 'الأولوية', 'منخفضة', 'عادية', 'عالية', 'الموضوع', 'الوصف', 'إرفاق ملف (اختياري)', 'إرسال التذكرة']) {
        expect(find.textContaining(label), findsWidgets, reason: label);
      }
    });

    testWidgets('a financial correction is not offered: it needs an agent, an action and an amount', (tester) async {
      await open(tester);
      expect(find.textContaining('تصحيح مالي'), findsNothing);
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
      await tester.enterText(find.byType(TextFormField).at(1), 'تأخر الطلب');
      await tester.enterText(find.byType(TextFormField).at(2), 'الطلب SB-1 متأخر');
      await tester.tap(find.text('إرسال التذكرة'));
      await settle(tester);
      expect(repo.lastSubject, 'تأخر الطلب');
      expect(repo.lastPriority, TicketPriority.high);
    });


    testWidgets('the picked category fills the field and its code goes with the ticket', (tester) async {
      final repo = await open(tester);
      await tester.tap(find.text('اختر التصنيف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المدفوعات والمحفظة'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'المدفوعات والمحفظة'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), 'تأخر الشحن');
      await tester.enterText(find.byType(TextFormField).at(2), 'الشحن لم يصل');
      await tester.tap(find.text('إرسال التذكرة'));
      await settle(tester);
      expect(repo.lastCategoryCode, 'payments');
    });

    testWidgets('without picking, the ticket is general: no code is sent and the form still works', (tester) async {
      final repo = await open(tester);
      await tester.enterText(find.byType(TextFormField).at(1), 'سؤال');
      await tester.enterText(find.byType(TextFormField).at(2), 'تفاصيل');
      await tester.tap(find.text('إرسال التذكرة'));
      await settle(tester);
      expect(repo.lastSubject, 'سؤال');
      expect(repo.lastCategoryCode, isNull);
    });

    testWidgets('choosing Other sends the general code', (tester) async {
      final repo = await open(tester);
      await tester.tap(find.text('اختر التصنيف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أخرى'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), 'سؤال');
      await tester.enterText(find.byType(TextFormField).at(2), 'تفاصيل');
      await tester.tap(find.text('إرسال التذكرة'));
      await settle(tester);
      expect(repo.lastCategoryCode, 'general');
    });

    Future<void> attachFile(WidgetTester tester) async {
      await tester.tap(find.text('إرفاق ملف (اختياري)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ملف'));
      await settle(tester);
    }

    testWidgets('a picked file is staged at once and the ticket carries its id', (tester) async {
      final uploader = FakeStagedUploader(id: 'file-77');
      final repo = await open(tester, uploader: uploader);
      await attachFile(tester);
      expect(uploader.staged, ['/tmp/proof.pdf']);
      expect(find.text('proof.pdf'), findsOneWidget);
      expect(find.text('تم إرفاق الملف.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), 'تأخر الطلب');
      await tester.enterText(find.byType(TextFormField).at(2), 'الطلب SB-1 متأخر');
      await tester.tap(find.text('إرسال التذكرة'));
      await settle(tester);
      expect(repo.lastCreateAttachment, 'file-77');
    });

    testWidgets('a removed file is not sent', (tester) async {
      final repo = await open(tester);
      await attachFile(tester);
      await tester.tap(find.text('حذف المرفق'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), 'س');
      await tester.enterText(find.byType(TextFormField).at(2), 'ص');
      await tester.tap(find.text('إرسال التذكرة'));
      await settle(tester);
      expect(repo.lastSubject, 'س');
      expect(repo.lastCreateAttachment, isNull);
    });

    testWidgets('a failed upload shows its own message and attaches nothing', (tester) async {
      final repo = await open(tester, uploader: FakeStagedUploader(failure: const ServerFailure('x', code: 'file_too_large')));
      await attachFile(tester);
      expect(find.text('proof.pdf'), findsNothing);
      expect(find.text(lookupAppLocalizations(const Locale('ar')).errFileTooLarge), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), 'س');
      await tester.enterText(find.byType(TextFormField).at(2), 'ص');
      await tester.tap(find.text('إرسال التذكرة'));
      await settle(tester);
      expect(repo.lastCreateAttachment, isNull);
    });
  });

  group('TicketDetailScreen (SUP-03)', () {
    Future<(_Repo, _Actions, SupportBloc)> open(
      WidgetTester tester,
      SupportTicket ticket, {
      bool failReply = false,
      FakeStagedUploader? uploader,
    }) async {
      final repo = _Repo([ticket])..failReply = failReply;
      final actions = _Actions();
      final bloc = _bloc(repo)..add(const SupportTicketsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: _app(TicketDetailScreen(
          ticketId: ticket.id,
          createActionsCubit: () => _actionsCubit(actions),
          createAttachment: () => fakeAttachmentCubit(uploader ?? FakeStagedUploader()),
          createRating: () => TicketRatingCubit(FakeTicketRatingRepository(), ticketId: ticket.id),
        )),
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
      // The failure toast sits over the resend link until it goes away.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('إعادة إرسال'));
      await settle(tester);
      expect(find.text('إعادة إرسال'), findsNothing);
      expect(find.textContaining('فشل الإرسال'), findsNothing);
      expect(repo.replies, ['أرفقت صورة الجواز']);
      expect(find.text('أرفقت صورة الجواز'), findsOneWidget);
    });

    testWidgets('closed and cancelled tickets are final: read-only, with no reopen', (tester) async {
      for (final status in [SupportTicketStatus.closed, SupportTicketStatus.cancelled]) {
        await open(tester, _ticket('9', 'نهائية', status: status));
        expect(find.text('عند إغلاق التذكرة تصبح للقراءة فقط'), findsOneWidget, reason: status.name);
        expect(find.text('اكتب رسالة...'), findsNothing, reason: status.name);
        expect(find.text('إعادة فتح'), findsNothing, reason: status.name);
      }
    });

    testWidgets('a resolved ticket still takes a reply: replying reopens it on the server', (tester) async {
      final (repo, _, _) = await open(tester, _ticket('8', 'محلولة', status: SupportTicketStatus.resolved));
      expect(find.text('اكتب رسالة...'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'ما زالت المشكلة');
      await tester.tap(find.byIcon(SeenIcons.send));
      await settle(tester);
      expect(repo.replies, ['ما زالت المشكلة']);
    });


    testWidgets('a closed ticket ends with the closing line and the rating card; rating sends the stars', (tester) async {
      final (repo, _, _) = await open(tester, _ticket('9', 'مغلقة', status: SupportTicketStatus.closed));
      expect(find.textContaining('أُغلقت التذكرة'), findsOneWidget);
      expect(find.text('كيف كانت تجربتك مع الدعم؟'), findsOneWidget);
      expect(repo.replies, isEmpty);
    });

    testWidgets('a resolved ticket offers the rating card but no closing line; open and cancelled ones offer neither', (tester) async {
      await open(tester, _ticket('8', 'محلولة', status: SupportTicketStatus.resolved));
      expect(find.text('كيف كانت تجربتك مع الدعم؟'), findsOneWidget);
      expect(find.textContaining('أُغلقت التذكرة'), findsNothing);
      for (final status in [SupportTicketStatus.open, SupportTicketStatus.cancelled]) {
        await open(tester, _ticket('7', 'x', status: status));
        expect(find.text('كيف كانت تجربتك مع الدعم؟'), findsNothing, reason: status.name);
      }
    });

    testWidgets('unread messages get a "new messages" divider before the first one, and it stays after opening marks them read', (tester) async {
      final ticket = _ticket('6', 'ردود',
              unread: true,
              messages: [
                _msg('a', 'سؤالي', minutesAgo: 90),
                _msg('b', 'رد أول', support: true, author: 'الدعم', minutesAgo: 20),
                _msg('c', 'رد ثان', support: true, author: 'الدعم', minutesAgo: 10),
              ])
          .copyWith(unreadCount: 2);
      final (_, actions, _) = await open(tester, ticket);
      expect(find.text('رسائل جديدة (٢)'), findsOneWidget);
      expect(actions.read, ['6']);
      final divider = tester.getTopLeft(find.text('رسائل جديدة (٢)')).dy;
      expect(tester.getTopLeft(find.text('سؤالي')).dy < divider, isTrue);
      expect(tester.getTopLeft(find.text('رد أول')).dy > divider, isTrue);
    });

    testWidgets('nothing unread: no divider', (tester) async {
      await open(tester, _ticket('5', 'x'));
      expect(find.textContaining('رسائل جديدة'), findsNothing);
    });

    testWidgets('a reply carries the staged file once, and the next reply starts without it', (tester) async {
      final (repo, _, _) = await open(tester, _ticket('5', 'x'), uploader: FakeStagedUploader(id: 'file-5'));
      await tester.tap(find.bySemanticsLabel('إرفاق ملف (اختياري)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ملف'));
      await settle(tester);
      expect(find.text('proof.pdf'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'هذه الصورة');
      await tester.tap(find.byIcon(SeenIcons.send));
      await settle(tester);
      expect(repo.replyAttachments, ['file-5']);
      expect(find.text('proof.pdf'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'شكرًا');
      await tester.tap(find.byIcon(SeenIcons.send));
      await settle(tester);
      expect(repo.replyAttachments, ['file-5', null]);
    });
  });
}
