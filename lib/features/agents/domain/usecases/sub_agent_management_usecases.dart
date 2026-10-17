import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/new_sub_agent.dart';
import '../entities/sub_agent.dart';
import '../entities/sub_agent_profile.dart';
import '../repositories/agents_repository.dart';

class CreateSubAgentUseCase {
  const CreateSubAgentUseCase(this._repository);
  final AgentsRepository _repository;

  Future<Either<Failure, SubAgent>> call(NewSubAgent newSubAgent) =>
      _repository.createSubAgent(newSubAgent);
}

class UpdateCreditLimitUseCase {
  const UpdateCreditLimitUseCase(this._repository);
  final AgentsRepository _repository;

  Future<Either<Failure, SubAgent>> call(
          {required String subAgentId, required int limitCents}) =>
      _repository.updateCreditLimit(
          subAgentId: subAgentId, limitCents: limitCents);
}

class GetSubAgentProfileUseCase {
  const GetSubAgentProfileUseCase(this._repository);
  final AgentsRepository _repository;

  Future<Either<Failure, SubAgentProfile>> call(String subAgentId) =>
      _repository.getSubAgentProfile(subAgentId);
}

class SetSubAgentActiveUseCase {
  const SetSubAgentActiveUseCase(this._repository);
  final AgentsRepository _repository;

  Future<Either<Failure, SubAgent>> call(
          {required String subAgentId, required bool active, String? reason}) =>
      _repository.setSubAgentActive(
          subAgentId: subAgentId, active: active, reason: reason);
}
