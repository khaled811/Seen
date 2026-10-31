import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/agency_profile.dart';
import '../../domain/entities/service_margin.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/profile_repositories.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements AgencyRepository, MarginsRepository, TeamRepository {
  ProfileRepositoryImpl({required ProfileRemoteDataSource remote}) : _remote = remote;

  final ProfileRemoteDataSource _remote;

  @override
  Future<Either<Failure, AgencyProfile>> getProfile() => _remote.getAgencyProfile();

  @override
  Future<Either<Failure, MarginsOverview>> getMargins(String agentId) => _remote.getMargins(agentId);

  @override
  Future<Either<Failure, MarginsOverview>> saveMargins(String agentId, Map<String, int> changes) =>
      _remote.saveMargins(agentId, changes);

  @override
  Future<Either<Failure, List<TeamMember>>> getMembers() => _remote.getTeam();

  @override
  Future<Either<Failure, TeamMember>> invite(InviteDraft draft) => _remote.inviteMember(draft);

  @override
  Future<Either<Failure, TeamMember>> changeRole(String memberId, TeamRole role) =>
      _remote.changeMemberRole(memberId, role);

}
