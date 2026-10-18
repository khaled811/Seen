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
  Future<Either<Failure, AgencyProfile>> getProfile() async => (await _remote.getAgencyProfile()).map((d) => d.entity);

  @override
  Future<Either<Failure, MarginsOverview>> getMargins() async => (await _remote.getMargins()).map((d) => d.entity);

  @override
  Future<Either<Failure, MarginsOverview>> saveMargins(Map<String, int> changes) async =>
      (await _remote.saveMargins(changes)).map((d) => d.entity);

  @override
  Future<Either<Failure, List<TeamMember>>> getMembers() => _remote.getTeam();

  @override
  Future<Either<Failure, TeamMember>> invite(InviteDraft draft) => _remote.inviteMember(draft);

  @override
  Future<Either<Failure, TeamMember>> changeRole(String memberId, TeamRole role) =>
      _remote.changeMemberRole(memberId, role);

  @override
  Future<Either<Failure, TeamMember>> setActive(String memberId, {required bool active}) =>
      _remote.setMemberActive(memberId, active: active);

  @override
  Future<Either<Failure, void>> resendInvite(String memberId) async => (await _remote.resendInvite(memberId)).map((_) {});

  @override
  Future<Either<Failure, void>> cancelInvite(String memberId) async => (await _remote.cancelInvite(memberId)).map((_) {});
}
