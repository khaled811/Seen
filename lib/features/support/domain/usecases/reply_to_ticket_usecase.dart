import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/support_ticket.dart';
import '../repositories/support_repository.dart';

class ReplyToTicketUseCase {
  const ReplyToTicketUseCase(this._repository);

  final SupportRepository _repository;

  Future<Either<Failure, SupportTicket>> call({
    required String ticketId,
    required String message,
  }) =>
      _repository.replyToTicket(ticketId: ticketId, message: message);
}
