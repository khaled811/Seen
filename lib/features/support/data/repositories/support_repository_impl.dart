import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/in_app_notification.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/entities/ticket_message.dart';
import '../../domain/repositories/support_repository.dart';
import '../datasources/support_remote_data_source.dart';

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl({required SupportRemoteDataSource remote}) : _remote = remote;

  final SupportRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets() => _remote.getTickets();

  @override
  Future<Either<Failure, SupportTicket>> getTicket(String ticketId) => _remote.getTicket(ticketId);

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
    String? attachmentFileId,
    String? categoryCode,
  }) =>
      _remote.createTicket(
        category: category,
        subject: subject,
        message: message,
        requestId: requestId,
        priority: priority,
        attachmentFileId: attachmentFileId,
        categoryCode: categoryCode,
      );

  @override
  Future<Either<Failure, TicketMessage>> replyToTicket({required String ticketId, required String message, String? attachmentFileId}) =>
      _remote.replyToTicket(ticketId: ticketId, message: message, attachmentFileId: attachmentFileId);

  @override
  Future<Either<Failure, NotificationsPage>> getNotifications({bool unreadOnly = false, int limit = 20, int offset = 0}) =>
      _remote.getNotifications(unreadOnly: unreadOnly, limit: limit, offset: offset);

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() => _remote.getUnreadNotificationCount();

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) => _remote.markNotificationRead(notificationId);

  @override
  Future<Either<Failure, int>> markAllNotificationsRead() => _remote.markAllNotificationsRead();
}
