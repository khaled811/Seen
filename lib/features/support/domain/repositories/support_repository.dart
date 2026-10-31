import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../entities/in_app_notification.dart';
import '../entities/support_ticket.dart';
import '../entities/ticket_message.dart';

abstract interface class SupportRepository {
  /// The agency's tickets (without their messages: see [getTicket]).
  Future<Either<Failure, List<SupportTicket>>> getTickets();

  /// One ticket with its thread.
  Future<Either<Failure, SupportTicket>> getTicket(String ticketId);

  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
    String? attachmentFileId,
    String? categoryCode,
  });

  /// Appends [message] to [ticketId]'s thread and returns the message the server
  /// stored. Not idempotent: the caller never resends it on its own.
  Future<Either<Failure, TicketMessage>> replyToTicket({
    required String ticketId,
    required String message,
    String? attachmentFileId,
  });

  Future<Either<Failure, NotificationsPage>> getNotifications({bool unreadOnly = false, int limit = 20, int offset = 0});

  /// The unread total of the whole inbox.
  Future<Either<Failure, int>> getUnreadNotificationCount();

  /// False when the server did not mark it (not found / not the caller's).
  Future<Either<Failure, bool>> markNotificationRead(String notificationId);

  /// How many were marked.
  Future<Either<Failure, int>> markAllNotificationsRead();
}
