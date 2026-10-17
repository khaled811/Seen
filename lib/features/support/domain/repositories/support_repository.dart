import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../entities/in_app_notification.dart';
import '../entities/support_ticket.dart';

abstract interface class SupportRepository {
  Future<Either<Failure, List<SupportTicket>>> getTickets();

  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
  });

  /// Appends [message] to [ticketId]'s thread. Not named in Task 10's own
  /// use-case list, but required for the detail screen's "chat-style
  /// messages/replies" to actually be usable — a read-only chat isn't one.
  Future<Either<Failure, SupportTicket>> replyToTicket({
    required String ticketId,
    required String message,
  });

  Future<Either<Failure, List<InAppNotification>>> getNotifications();

  Future<Either<Failure, void>> markNotificationRead(String notificationId);

  /// Not named in Task 10's own use-case list, but required to fulfil its
  /// business rule #2 ("Mark all as read").
  Future<Either<Failure, void>> markAllNotificationsRead();
}
