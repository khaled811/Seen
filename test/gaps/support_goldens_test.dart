// Loaded-state goldens of the support screens that get an added element in the GAPS work
// (design/gaps SPEC §0.2): new ticket (category picker) and the thread of a closed ticket
// (rating card). Baselines captured BEFORE those screens were edited. Fixed dates, so the day
// labels do not depend on the clock.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
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
import 'package:seen_booking/features/support/presentation/screens/ticket_detail_screen.dart';

import '../support/attachment_fakes.dart';

final _day = DateTime(2026, 9, 1, 12);

SupportTicket _ticket(String id, SupportTicketStatus status) => SupportTicket(
      id: id,
      referenceId: 'TK-$id',
      category: TicketCategory.general,
      priority: TicketPriority.normal,
      subject: 'تعذّر رفع جواز السفر',
      status: status,
      createdAt: _day,
      messages: [
        TicketMessage(id: '$id-1', authorName: 'You', isSupportReply: false, body: 'لا أستطيع رفع صورة الجواز', sentAt: _day),
        TicketMessage(
          id: '$id-2',
          authorName: 'فريق الدعم',
          isSupportReply: true,
          body: 'تم حل المشكلة، جرّب الآن من فضلك',
          sentAt: _day.add(const Duration(minutes: 20)),
        ),
      ],
    );

class _Repo implements SupportRepository {
  _Repo(this.tickets);

  final List<SupportTicket> tickets;

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets() async => Right(tickets);

  @override
  Future<Either<Failure, SupportTicket>> getTicket(String ticketId) async => Right(tickets.firstWhere((t) => t.id == ticketId));

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
    String? attachmentFileId,
    String? categoryCode,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, TicketMessage>> replyToTicket({required String ticketId, required String message, String? attachmentFileId}) =>
      throw UnimplementedError();

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
  @override
  Future<Either<Failure, void>> markRead(String ticketId) async => const Right(null);
}

Widget _app(SupportBloc bloc, Widget home) => BlocProvider.value(
      value: bloc,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
      ),
    );

Future<void> _shot(WidgetTester tester, String name, Widget Function(SupportBloc bloc) screen, List<SupportTicket> tickets) async {
  final repo = _Repo(tickets);
  final bloc = SupportBloc(
    getTicketsUseCase: GetTicketsUseCase(repo),
    createTicketUseCase: CreateTicketUseCase(repo),
    replyToTicketUseCase: ReplyToTicketUseCase(repo),
    getTicketUseCase: GetTicketUseCase(repo),
  )..add(const SupportTicketsLoadRequested());
  addTearDown(() => bloc.close().ignore());
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(bloc, screen(bloc)));
  await tester.runAsync(() async {
    while (bloc.state is! SupportLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  });
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await screenMatchesGolden(tester, name);
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await loadAppFonts();
    InjectionContainer.instance.init();
  });

  testGoldens(
    'new ticket',
    (t) => _shot(t, 'support_create_ticket', (_) => CreateTicketScreen(createAttachment: () => fakeAttachmentCubit(FakeStagedUploader())), const []),
  );

  testGoldens(
    'closed ticket thread',
    (t) => _shot(
      t,
      'support_ticket_closed',
      (_) => TicketDetailScreen(
        ticketId: '7',
        createActionsCubit: () => TicketActionsCubit(markRead: MarkTicketReadUseCase(_Actions())),
        createAttachment: () => fakeAttachmentCubit(FakeStagedUploader()),
      ),
      [_ticket('7', SupportTicketStatus.closed)],
    ),
  );
}
