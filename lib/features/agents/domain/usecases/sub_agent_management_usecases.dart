import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/new_sub_agent.dart';
import '../entities/sub_agent.dart';
import '../repositories/agents_repository.dart';

class CreateSubAgentUseCase {
  const CreateSubAgentUseCase(this._repository);
  final AgentsRepository _repository;

  Future<Either<Failure, SubAgent>> call(NewSubAgent newSubAgent) => _repository.createSubAgent(newSubAgent);
}

class UpdateCreditLimitUseCase {
  const UpdateCreditLimitUseCase(this._repository);
  final AgentsRepository _repository;

  Future<Either<Failure, SubAgent>> call({required String subAgentId, required int limitCents}) =>
      _repository.updateCreditLimit(subAgentId: subAgentId, limitCents: limitCents);
}
