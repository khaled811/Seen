import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/support_ticket.dart';
import '../repositories/support_repository.dart';

class GetTicketsUseCase {
  const GetTicketsUseCase(this._repository);

  final SupportRepository _repository;

  Future<Either<Failure, List<SupportTicket>>> call() => _repository.getTickets();
}
