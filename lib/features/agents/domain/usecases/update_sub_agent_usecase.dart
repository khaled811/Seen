import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/sub_agent_edit_repository.dart';

class UpdateSubAgentUseCase {
  const UpdateSubAgentUseCase(this._repository);

  final SubAgentEditRepository _repository;

  Future<Either<Failure, void>> call({required String agentId, String? name, String? ownerFullName, String? ownerEmail}) =>
      _repository.update(agentId: agentId, name: name, ownerFullName: ownerFullName, ownerEmail: ownerEmail);
}
