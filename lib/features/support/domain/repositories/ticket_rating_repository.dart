import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

/// How the agent rates a resolved or closed ticket (`rateTicket`, 1-5, once). Kept apart from
/// [SupportRepository], like the other ticket actions, so that contract stays as it was.
abstract interface class TicketRatingRepository {
  /// Fails with `already_rated` when the ticket was rated before and `ticket_not_resolved` when it
  /// is still open. The server takes no comment.
  Future<Either<Failure, void>> rate(String ticketId, int rating);
}
