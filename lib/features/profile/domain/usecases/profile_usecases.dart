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

  Future<Either<Failure, MarginsOverview>> call() => _repository.getMargins();
}

class SaveMarginsUseCase {
  const SaveMarginsUseCase(this._repository);

  final MarginsRepository _repository;

  Future<Either<Failure, MarginsOverview>> call(Map<String, int> changes) => _repository.saveMargins(changes);
}

/// The team screen's operations, grouped (one repository, one owner screen).
class TeamUseCases {
  const TeamUseCases(this._repository);

  final TeamRepository _repository;

  Future<Either<Failure, List<TeamMember>>> list() => _repository.getMembers();

  Future<Either<Failure, TeamMember>> invite(InviteDraft draft) => _repository.invite(draft);

  Future<Either<Failure, TeamMember>> changeRole(String id, TeamRole role) => _repository.changeRole(id, role);

  Future<Either<Failure, TeamMember>> setActive(String id, {required bool active}) =>
      _repository.setActive(id, active: active);

  Future<Either<Failure, void>> resendInvite(String id) => _repository.resendInvite(id);

  Future<Either<Failure, void>> cancelInvite(String id) => _repository.cancelInvite(id);
}
