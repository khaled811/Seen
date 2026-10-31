import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/agency_profile.dart';
import '../entities/service_margin.dart';
import '../entities/team_member.dart';

abstract interface class AgencyRepository {
  Future<Either<Failure, AgencyProfile>> getProfile();
}

abstract interface class MarginsRepository {
  /// The margins the agency gives [agentId] (one of its sub-agencies) on the services
  /// enabled for it.
  Future<Either<Failure, MarginsOverview>> getMargins(String agentId);

  /// [changes]: service id -> new value (cents or basis points, per the service's kind).
  /// Returns the overview as the server now has it (the server is the source of truth).
  Future<Either<Failure, MarginsOverview>> saveMargins(String agentId, Map<String, int> changes);
}

abstract interface class TeamRepository {
  Future<Either<Failure, List<TeamMember>>> getMembers();

  Future<Either<Failure, TeamMember>> invite(InviteDraft draft);

  Future<Either<Failure, TeamMember>> changeRole(String memberId, TeamRole role);

}
