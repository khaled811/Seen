import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/agency_profile.dart';
import '../entities/service_margin.dart';
import '../entities/team_member.dart';
import '../repositories/profile_repositories.dart';

class GetAgencyProfileUseCase {
  const GetAgencyProfileUseCase(this._repository);

  final AgencyRepository _repository;

  Future<Either<Failure, AgencyProfile>> call() => _repository.getProfile();
}

class GetMarginsUseCase {
  const GetMarginsUseCase(this._repository);

  final MarginsRepository _repository;

  Future<Either<Failure, MarginsOverview>> call(String agentId) => _repository.getMargins(agentId);
}

class SaveMarginsUseCase {
  const SaveMarginsUseCase(this._repository);

  final MarginsRepository _repository;

  Future<Either<Failure, MarginsOverview>> call(String agentId, Map<String, int> changes) =>
      _repository.saveMargins(agentId, changes);
}

/// The team screen's operations, grouped (one repository, one owner screen).
class TeamUseCases {
  const TeamUseCases(this._repository);

  final TeamRepository _repository;

  Future<Either<Failure, List<TeamMember>>> list() => _repository.getMembers();

  Future<Either<Failure, TeamMember>> invite(InviteDraft draft) => _repository.invite(draft);

  Future<Either<Failure, TeamMember>> changeRole(String id, TeamRole role) => _repository.changeRole(id, role);

}
