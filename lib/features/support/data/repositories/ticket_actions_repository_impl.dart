import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/ticket_actions_repository.dart';
import '../datasources/support_remote_data_source.dart';

class TicketActionsRepositoryImpl implements TicketActionsRepository {
  TicketActionsRepositoryImpl({required SupportRemoteDataSource remote}) : _remote = remote;

  final SupportRemoteDataSource _remote;

  @override
  Future<Either<Failure, void>> markRead(String ticketId) async =>
      (await _remote.markTicketRead(ticketId)).map((_) {});

  @override
  Future<Either<Failure, SupportTicket>> reopen(String ticketId) async =>
      (await _remote.reopenTicket(ticketId)).map((dto) => dto.toEntity());
}
