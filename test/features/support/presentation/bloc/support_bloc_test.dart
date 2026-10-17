import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/support/domain/entities/in_app_notification.dart';
import 'package:seen_booking/features/support/domain/entities/support_ticket.dart';
import 'package:seen_booking/features/support/domain/entities/ticket_message.dart';
import 'package:seen_booking/features/support/domain/repositories/support_repository.dart';
import 'package:seen_booking/features/support/domain/usecases/create_ticket_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/get_tickets_usecase.dart';
import 'package:seen_booking/features/support/domain/usecases/reply_to_ticket_usecase.dart';
import 'package:seen_booking/features/support/presentation/bloc/support_bloc.dart';
import 'package:seen_booking/features/support/presentation/bloc/support_event.dart';
import 'package:seen_booking/features/support/presentation/bloc/support_state.dart';

SupportTicket _ticket(String id, {List<TicketMessage> messages = const []}) => SupportTicket(
      id: id,
      referenceId: 'TCK-$id',
      category: TicketCategory.general,
      priority: TicketPriority.normal,
      subject: 'Existing ticket $id',
      status: SupportTicketStatus.open,
      createdAt: DateTime(2026, 1, 1),
      messages: messages,
    );

/// Support entities aren't imported for use in tests directly used with
/// Notifications; irrelevant here.
class _FakeSupportRepository implements SupportRepository {
  Either<Failure, List<SupportTicket>> ticketsResult = Right([_ticket('1')]);
  Either<Failure, SupportTicket>? createResult;
  Either<Failure, SupportTicket>? replyResult;
  String? lastCreateSubject;
  String? lastReplyMessage;

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets() async => ticketsResult;

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
  }) async {
    lastCreateSubject = subject;
    return createResult ??
        Right(
          SupportTicket(
            id: 'new-1',
            referenceId: 'TCK-new-1',
            category: category,
            priority: TicketPriority.normal,
            subject: subject,
            requestId: requestId,
            status: SupportTicketStatus.open,
            createdAt: DateTime(2026, 1, 2),
            messages: [
              TicketMessage(
                id: 'new-1-msg-1',
                authorName: 'You',
                isSupportReply: false,
                body: message,
                sentAt: DateTime(2026, 1, 2),
              ),
            ],
          ),
        );
  }

  @override
  Future<Either<Failure, SupportTicket>> replyToTicket({
    required String ticketId,
    required String message,
  }) async {
    lastReplyMessage = message;
    return replyResult ??
        Right(
          _ticket(
            ticketId,
            messages: [
              TicketMessage(
                id: '$ticketId-msg-new',
                authorName: 'You',
                isSupportReply: false,
                body: message,
                sentAt: DateTime(2026, 1, 3),
              ),
            ],
          ),
        );
  }

  @override
  Future<Either<Failure, List<InAppNotification>>> getNotifications() =>
      throw UnimplementedError('Not used by SupportBloc');

  @override
  Future<Either<Failure, void>> markNotificationRead(String notificationId) =>
      throw UnimplementedError('Not used by SupportBloc');

  @override
  Future<Either<Failure, void>> markAllNotificationsRead() =>
      throw UnimplementedError('Not used by SupportBloc');
}

void main() {
  late _FakeSupportRepository repository;
  late SupportBloc bloc;

  setUp(() {
    repository = _FakeSupportRepository();
    bloc = SupportBloc(
      getTicketsUseCase: GetTicketsUseCase(repository),
      createTicketUseCase: CreateTicketUseCase(repository),
      replyToTicketUseCase: ReplyToTicketUseCase(repository),
    );
  });

  tearDown(() => bloc.close());

  Future<SupportLoaded> load() async {
    bloc.add(const SupportTicketsLoadRequested());
    return await bloc.stream.firstWhere((s) => s is SupportLoaded) as SupportLoaded;
  }

  test('initial state is SupportInitial', () {
    expect(bloc.state, const SupportInitial());
  });

  group('ticket creation', () {
    test('prepends the new ticket and sets createdTicketId on success', () async {
      await load();
      bloc.add(
        const SupportTicketCreateSubmitted(
          category: TicketCategory.general,
          subject: 'Help with visa',
          message: 'How long does this take?',
        ),
      );

      await bloc.stream.firstWhere(
        (s) => s is SupportLoaded && s.createStatus == CreateTicketStatus.submitting,
      );
      final done = await bloc.stream.firstWhere(
        (s) => s is SupportLoaded && s.createStatus == CreateTicketStatus.success,
      ) as SupportLoaded;

      expect(done.tickets.first.subject, 'Help with visa');
      expect(done.tickets, hasLength(2)); // prepended, original ticket kept
      expect(done.createdTicketId, 'new-1');
      expect(repository.lastCreateSubject, 'Help with visa');
    });

    test('surfaces a failure without touching the ticket list', () async {
      await load();
      repository.createResult = const Left(ServerFailure('subject too long'));

      bloc.add(
        SupportTicketCreateSubmitted(
          category: TicketCategory.general,
          subject: 'x' * 500,
          message: 'test',
        ),
      );
      final failed = await bloc.stream.firstWhere(
        (s) => s is SupportLoaded && s.createStatus == CreateTicketStatus.failure,
      ) as SupportLoaded;

      expect(failed.createError, 'subject too long');
      expect(failed.tickets, hasLength(1));
    });

    test('SupportTicketCreateAcknowledged clears the one-shot id', () async {
      await load();
      bloc.add(
        const SupportTicketCreateSubmitted(
          category: TicketCategory.general,
          subject: 'Help',
          message: 'test',
        ),
      );
      await bloc.stream.firstWhere(
        (s) => s is SupportLoaded && s.createdTicketId != null,
      );

      bloc.add(const SupportTicketCreateAcknowledged());
      final cleared = await bloc.stream.first as SupportLoaded;
      expect(cleared.createdTicketId, isNull);
    });
  });

  group('replies', () {
    test('appends the reply to the matching ticket', () async {
      await load();
      bloc.add(const SupportTicketReplySubmitted(ticketId: '1', message: 'Following up'));

      final done = await bloc.stream.firstWhere(
        (s) => s is SupportLoaded && s.replyStatus == ReplyStatus.success,
      ) as SupportLoaded;

      final updated = done.ticketById('1')!;
      expect(updated.messages, hasLength(1));
      expect(updated.messages.first.body, 'Following up');
    });
  });
}
