import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/agents_repository.dart';

class ApproveSubAgentRequestUseCase {
  const ApproveSubAgentRequestUseCase(this._repository);

  final AgentsRepository _repository;

  Future<Either<Failure, void>> call(String requestId) =>
      _repository.approveRequest(requestId);
}
