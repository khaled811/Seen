import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/support_ticket.dart';

/// Marking a thread read and reopening a closed ticket (Figma SUP-01 / 03). Kept
/// apart from [SupportRepository] so the existing contract stays as it was.
abstract interface class TicketActionsRepository {
  Future<Either<Failure, void>> markRead(String ticketId);

  Future<Either<Failure, SupportTicket>> reopen(String ticketId);
}
