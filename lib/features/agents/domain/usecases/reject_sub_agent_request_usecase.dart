import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/agents_repository.dart';

class RejectSubAgentRequestUseCase {
  const RejectSubAgentRequestUseCase(this._repository);

  final AgentsRepository _repository;

  Future<Either<Failure, void>> call(String requestId, {required String reason}) =>
      _repository.rejectRequest(requestId, reason: reason);
}
