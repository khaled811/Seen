import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/support_ticket.dart';
import '../../domain/usecases/ticket_actions_usecases.dart';

enum TicketActionStatus { idle, working, reopened, failed }

class TicketActionsState extends Equatable {
  const TicketActionsState({this.status = TicketActionStatus.idle, this.ticket, this.message, this.seq = 0});

  final TicketActionStatus status;

  /// The reopened ticket, for the list to adopt.
  final SupportTicket? ticket;
  final String? message;

  /// Changes on every result so the screen reacts once per attempt.
  final int seq;

  @override
  List<Object?> get props => [status, ticket, message, seq];
}

/// What the ticket thread can do besides chatting: tell the server it was read,
/// and reopen a closed ticket (Figma SUP-03). One reopen at a time.
class TicketActionsCubit extends Cubit<TicketActionsState> {
  TicketActionsCubit({required MarkTicketReadUseCase markRead, required ReopenTicketUseCase reopen})
      : _markRead = markRead,
        _reopen = reopen,
        super(const TicketActionsState());

  final MarkTicketReadUseCase _markRead;
  final ReopenTicketUseCase _reopen;

  /// Best effort: failing to say "read" must never get in the agent's way.
  Future<void> markRead(String ticketId) async {
    await _markRead(ticketId);
  }

  Future<void> reopen(String ticketId) async {
    if (state.status == TicketActionStatus.working) return;
    emit(TicketActionsState(status: TicketActionStatus.working, seq: state.seq));
    final result = await _reopen(ticketId);
    if (isClosed) return;
    result.match(
      (failure) => emit(TicketActionsState(status: TicketActionStatus.failed, message: failure.message, seq: state.seq + 1)),
      (ticket) => emit(TicketActionsState(status: TicketActionStatus.reopened, ticket: ticket, seq: state.seq + 1)),
    );
  }
}
