import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/sub_agent_request_summary.dart';
import '../repositories/agents_repository.dart';

/// Not named in Task 09's own use-case list, but required to fulfil its
/// business rule #2 ("list requests... awaiting master agent approval") —
/// added alongside the four named use cases.
class GetPendingApprovalRequestsUseCase {
  const GetPendingApprovalRequestsUseCase(this._repository);

  final AgentsRepository _repository;

  Future<Either<Failure, List<SubAgentRequestSummary>>> call() =>
      _repository.getPendingApprovalRequests();
}
