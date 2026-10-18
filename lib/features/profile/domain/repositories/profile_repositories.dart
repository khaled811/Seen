import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/agency_profile.dart';
import '../entities/service_margin.dart';
import '../entities/team_member.dart';

abstract interface class AgencyRepository {
  Future<Either<Failure, AgencyProfile>> getProfile();
}

abstract interface class MarginsRepository {
  Future<Either<Failure, MarginsOverview>> getMargins();

  /// [changes]: service id -> new value (cents or basis points, per the service's kind).
  /// Returns the overview as the server now has it (the server is the source of truth).
  Future<Either<Failure, MarginsOverview>> saveMargins(Map<String, int> changes);
}

abstract interface class TeamRepository {
  Future<Either<Failure, List<TeamMember>>> getMembers();

  Future<Either<Failure, TeamMember>> invite(InviteDraft draft);

  Future<Either<Failure, TeamMember>> changeRole(String memberId, TeamRole role);

  Future<Either<Failure, TeamMember>> setActive(String memberId, {required bool active});

  Future<Either<Failure, void>> resendInvite(String memberId);

  Future<Either<Failure, void>> cancelInvite(String memberId);
}
