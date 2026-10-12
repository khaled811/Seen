import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/sub_agent.dart';
import '../repositories/agents_repository.dart';

class GetSubAgentsUseCase {
  const GetSubAgentsUseCase(this._repository);

  final AgentsRepository _repository;

  Future<Either<Failure, List<SubAgent>>> call() => _repository.getSubAgents();
}
