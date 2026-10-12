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
    on<SupportTicketReplySubmitted>(_onReplySubmitted, transformer: droppable());
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

  Future<void> _onReplySubmitted(
    SupportTicketReplySubmitted event,
    Emitter<SupportState> emit,
  ) async {
    final current = state;
    if (current is! SupportLoaded) return;

    emit(
      current.copyWith(
        replyStatus: ReplyStatus.submitting,
        replyingTicketId: event.ticketId,
        clearReplyError: true,
      ),
    );

    final result = await _replyToTicketUseCase(
      ticketId: event.ticketId,
      message: event.message,
    );
    final latest = state;
    if (latest is! SupportLoaded) return;
    emit(
      result.match(
        (failure) => latest.copyWith(
          replyStatus: ReplyStatus.failure,
          replyError: failure.message,
        ),
        (updatedTicket) => latest.copyWith(
          tickets: [
            for (final ticket in latest.tickets)
              if (ticket.id == updatedTicket.id) updatedTicket else ticket,
          ],
          replyStatus: ReplyStatus.success,
          clearReplyingTicketId: true,
        ),
      ),
    );
  }
}
