import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/support_ticket.dart';
import '../repositories/ticket_actions_repository.dart';

class MarkTicketReadUseCase {
  const MarkTicketReadUseCase(this._repository);

  final TicketActionsRepository _repository;

  Future<Either<Failure, void>> call(String ticketId) => _repository.markRead(ticketId);
}

class ReopenTicketUseCase {
  const ReopenTicketUseCase(this._repository);

  final TicketActionsRepository _repository;

  Future<Either<Failure, SupportTicket>> call(String ticketId) => _repository.reopen(ticketId);
}
