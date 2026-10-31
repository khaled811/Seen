import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/ticket_actions_usecases.dart';

/// What the ticket thread tells the server besides chatting: that it was read.
/// (Reopening is not an action: replying to a `resolved` or `waiting` ticket does
/// it, and `closed` / `cancelled` tickets are final.)
class TicketActionsCubit extends Cubit<void> {
  TicketActionsCubit({required MarkTicketReadUseCase markRead, this.onRead})
      : _markRead = markRead,
        super(null);

  final MarkTicketReadUseCase _markRead;

  /// Runs after a thread was marked read (the unread badge reads its count again).
  final void Function()? onRead;

  /// Best effort: failing to say "read" must never get in the agent's way.
  Future<void> markRead(String ticketId) async {
    await _markRead(ticketId);
    onRead?.call();
  }
}
