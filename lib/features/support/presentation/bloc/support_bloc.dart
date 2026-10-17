import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_ticket_usecase.dart';
import '../../domain/usecases/get_tickets_usecase.dart';
import '../../domain/usecases/reply_to_ticket_usecase.dart';
import 'support_event.dart';
import 'support_state.dart';

class SupportBloc extends Bloc<SupportEvent, SupportState> {
  SupportBloc({
    required GetTicketsUseCase getTicketsUseCase,
    required CreateTicketUseCase createTicketUseCase,
    required ReplyToTicketUseCase replyToTicketUseCase,
  })  : _getTicketsUseCase = getTicketsUseCase,
        _createTicketUseCase = createTicketUseCase,
        _replyToTicketUseCase = replyToTicketUseCase,
        super(const SupportInitial()) {
    on<SupportTicketsLoadRequested>(_onLoadRequested, transformer: droppable());
    on<SupportTicketCreateSubmitted>(_onCreateSubmitted, transformer: droppable());
    on<SupportTicketCreateAcknowledged>(_onCreateAcknowledged);
    // Messages go out one after the other, in the order they were typed.
    on<SupportTicketReplySubmitted>(_onReplySubmitted, transformer: sequential());
    on<SupportOutboxRetryRequested>(_onOutboxRetry, transformer: sequential());
    on<SupportTicketReplaced>(_onTicketReplaced);
    on<SupportTicketMarkedRead>(_onTicketMarkedRead);
  }

  final GetTicketsUseCase _getTicketsUseCase;
  final CreateTicketUseCase _createTicketUseCase;
  final ReplyToTicketUseCase _replyToTicketUseCase;

  Future<void> _onLoadRequested(
    SupportTicketsLoadRequested event,
    Emitter<SupportState> emit,
  ) async {
    emit(const SupportLoading());
    final result = await _getTicketsUseCase();
    emit(
      result.match(
        (failure) => SupportFailure(failure.message),
        (tickets) => SupportLoaded(tickets: tickets),
      ),
    );
  }

  Future<void> _onCreateSubmitted(
    SupportTicketCreateSubmitted event,
    Emitter<SupportState> emit,
  ) async {
    final current = state;
    if (current is! SupportLoaded) return;

    emit(
      current.copyWith(
        createStatus: CreateTicketStatus.submitting,
        clearCreateError: true,
      ),
    );

    final result = await _createTicketUseCase(
      category: event.category,
      subject: event.subject,
      message: event.message,
      requestId: event.requestId,
      priority: event.priority,
    );
    final latest = state;
    if (latest is! SupportLoaded) return;
    emit(
      result.match(
        (failure) => latest.copyWith(
          createStatus: CreateTicketStatus.failure,
          createError: failure.message,
        ),
        (ticket) => latest.copyWith(
          tickets: [ticket, ...latest.tickets],
          createStatus: CreateTicketStatus.success,
          createdTicketId: ticket.id,
        ),
      ),
    );
  }

  void _onCreateAcknowledged(
    SupportTicketCreateAcknowledged event,
    Emitter<SupportState> emit,
  ) {
    final current = state;
    if (current is! SupportLoaded) return;
    emit(
      current.copyWith(
        createStatus: CreateTicketStatus.idle,
        clearCreatedTicketId: true,
      ),
    );
  }

  int _outboxSeq = 0;

  Future<void> _onReplySubmitted(
    SupportTicketReplySubmitted event,
    Emitter<SupportState> emit,
  ) async {
    final current = state;
    if (current is! SupportLoaded) return;

    final item = OutboxMessage(
      localId: 'out-${_outboxSeq++}',
      ticketId: event.ticketId,
      body: event.message,
      sentAt: DateTime.now(),
    );
    emit(
      current.copyWith(
        outbox: [...current.outbox, item],
        replyStatus: ReplyStatus.submitting,
        replyingTicketId: event.ticketId,
        clearReplyError: true,
      ),
    );
    await _deliver(item, emit);
  }

  Future<void> _onOutboxRetry(
    SupportOutboxRetryRequested event,
    Emitter<SupportState> emit,
  ) async {
    final current = state;
    if (current is! SupportLoaded) return;
    final failed = current.outbox.where((m) => m.localId == event.localId && m.status == OutboxStatus.failed);
    if (failed.isEmpty) return;
    final item = failed.first.withStatus(OutboxStatus.sending);
    emit(
      current.copyWith(
        outbox: [for (final m in current.outbox) if (m.localId == item.localId) item else m],
        replyStatus: ReplyStatus.submitting,
        replyingTicketId: item.ticketId,
        clearReplyError: true,
      ),
    );
    await _deliver(item, emit);
  }

  Future<void> _deliver(OutboxMessage item, Emitter<SupportState> emit) async {
    final result = await _replyToTicketUseCase(ticketId: item.ticketId, message: item.body);
    final latest = state;
    if (latest is! SupportLoaded) return;
    emit(
      result.match(
        (failure) => latest.copyWith(
          outbox: [
            for (final m in latest.outbox)
              if (m.localId == item.localId) m.withStatus(OutboxStatus.failed) else m,
          ],
          replyStatus: ReplyStatus.failure,
          replyError: failure.message,
        ),
        (updatedTicket) => latest.copyWith(
          tickets: [
            for (final ticket in latest.tickets)
              if (ticket.id == updatedTicket.id) updatedTicket else ticket,
          ],
          outbox: [for (final m in latest.outbox) if (m.localId != item.localId) m],
          replyStatus: ReplyStatus.success,
          clearReplyingTicketId: true,
        ),
      ),
    );
  }

  void _onTicketReplaced(SupportTicketReplaced event, Emitter<SupportState> emit) {
    final current = state;
    if (current is! SupportLoaded) return;
    emit(
      current.copyWith(
        tickets: [for (final t in current.tickets) if (t.id == event.ticket.id) event.ticket else t],
      ),
    );
  }

  void _onTicketMarkedRead(SupportTicketMarkedRead event, Emitter<SupportState> emit) {
    final current = state;
    if (current is! SupportLoaded) return;
    final ticket = current.ticketById(event.ticketId);
    if (ticket == null || !ticket.hasUnreadReply) return;
    emit(
      current.copyWith(
        tickets: [
          for (final t in current.tickets)
            if (t.id == event.ticketId) t.copyWith(hasUnreadReply: false) else t,
        ],
      ),
    );
  }
}
