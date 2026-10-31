import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/support_ticket.dart';
import '../entities/ticket_message.dart';
import '../repositories/support_repository.dart';

class ReplyToTicketUseCase {
  const ReplyToTicketUseCase(this._repository);

  final SupportRepository _repository;

  Future<Either<Failure, TicketMessage>> call({
    required String ticketId,
    required String message,
    String? attachmentFileId,
  }) =>
      _repository.replyToTicket(ticketId: ticketId, message: message, attachmentFileId: attachmentFileId);
}

class GetTicketUseCase {
  const GetTicketUseCase(this._repository);

  final SupportRepository _repository;

  /// One ticket with its whole thread.
  Future<Either<Failure, SupportTicket>> call(String ticketId) => _repository.getTicket(ticketId);
}
