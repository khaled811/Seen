import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/in_app_notification.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';
import '../datasources/support_remote_data_source.dart';
import '../models/in_app_notification_dto.dart';
import '../models/support_ticket_dto.dart';

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl({required SupportRemoteDataSource remote}) : _remote = remote;

  final SupportRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets() async {
    final result = await _remote.getTickets();
    if (result case Left(:final value)) return Left(value);
    final dtos = (result as Right<Failure, List<SupportTicketDto>>).value;
    return Right(dtos.map((dto) => dto.toEntity()).toList());
  }

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
  }) async {
    final result = await _remote.createTicket(
      category: category,
      subject: subject,
      message: message,
      requestId: requestId,
      priority: priority,
    );
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, SupportTicketDto>).value;
    return Right(dto.toEntity());
  }

  @override
  Future<Either<Failure, SupportTicket>> replyToTicket({
    required String ticketId,
    required String message,
  }) async {
    final result = await _remote.replyToTicket(ticketId: ticketId, message: message);
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, SupportTicketDto>).value;
    return Right(dto.toEntity());
  }

  @override
  Future<Either<Failure, List<InAppNotification>>> getNotifications() async {
    final result = await _remote.getNotifications();
    if (result case Left(:final value)) return Left(value);
    final dtos = (result as Right<Failure, List<InAppNotificationDto>>).value;
    return Right(dtos.map((dto) => dto.toEntity()).toList());
  }

  @override
  Future<Either<Failure, void>> markNotificationRead(String notificationId) async {
    final result = await _remote.markNotificationRead(notificationId);
    if (result case Left(:final value)) return Left(value);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> markAllNotificationsRead() async {
    final result = await _remote.markAllNotificationsRead();
    if (result case Left(:final value)) return Left(value);
    return const Right(null);
  }
}
