// Domain (SupportTicketStatus) -> presentation (SeenStatus) reconciliation.
import '../../../../core/presentation/foundation/seen_status.dart';
import '../../domain/entities/support_ticket.dart';

extension SupportTicketStatusSeenMapping on SupportTicketStatus {
  SeenStatus get toSeenStatus => switch (this) {
        SupportTicketStatus.open => SeenStatus.pending,
        SupportTicketStatus.inProgress => SeenStatus.review,
        SupportTicketStatus.resolved => SeenStatus.approved,
        SupportTicketStatus.closed => SeenStatus.completed,
        SupportTicketStatus.unknown => SeenStatus.pending,
      };
}
