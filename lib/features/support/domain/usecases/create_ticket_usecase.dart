import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../entities/support_ticket.dart';
import '../repositories/support_repository.dart';

class CreateTicketUseCase {
  const CreateTicketUseCase(this._repository);

  final SupportRepository _repository;

  Future<Either<Failure, SupportTicket>> call({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
    String? attachmentFileId,
    String? categoryCode,
  }) =>
      _repository.createTicket(
        category: category,
        subject: subject,
        message: message,
        requestId: requestId,
        priority: priority,
        attachmentFileId: attachmentFileId,
        categoryCode: categoryCode,
      );
}
