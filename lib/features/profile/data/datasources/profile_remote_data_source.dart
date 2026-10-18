import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/team_member.dart';
import '../models/profile_dtos.dart';

/// Raw GraphQL access for agency details, margins and the team.
///
/// TODO(backend-contract): placeholder schema; see docs/BACKEND_MIGRATION_GAPS.md
/// section 33.
abstract interface class ProfileRemoteDataSource {
  Future<Either<Failure, AgencyProfileDto>> getAgencyProfile();

  Future<Either<Failure, MarginsOverviewDto>> getMargins();

  Future<Either<Failure, MarginsOverviewDto>> saveMargins(Map<String, int> changes);

  Future<Either<Failure, List<TeamMember>>> getTeam();

  Future<Either<Failure, TeamMember>> inviteMember(InviteDraft draft);

  Future<Either<Failure, TeamMember>> changeMemberRole(String id, TeamRole role);

  Future<Either<Failure, TeamMember>> setMemberActive(String id, {required bool active});

  Future<Either<Failure, bool>> resendInvite(String id);

  Future<Either<Failure, bool>> cancelInvite(String id);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl({required GraphQLService graphQLService}) : _g = graphQLService;

  final GraphQLService _g;

  static const _marginsFields = r'''
    margins { serviceId serviceName kind value editable iconKey }
    history { serviceName kind from to at by }
  ''';
  static const _memberFields = 'id name role status branchName';

  static final _profileDoc = gql(r'''
    query AgencyProfile {
      agencyProfile {
        name licenseNumber city managerName verification verifiedAt
        documents { id kind expiresAt viewUrl }
      }
    }
  ''');

  static final _marginsDoc = gql('''
    query ServiceMargins {
      serviceMargins { $_marginsFields }
    }
  ''');

  static final _saveMarginsDoc = gql('''
    mutation SaveServiceMargins(\$changes: [MarginChangeInput!]!) {
      saveServiceMargins(changes: \$changes) { $_marginsFields }
    }
  ''');

  static final _teamDoc = gql('''
    query TeamMembers {
      teamMembers { $_memberFields }
    }
  ''');

  static final _inviteDoc = gql('''
    mutation InviteMember(\$name: String!, \$phone: String!, \$role: String!, \$branchName: String!) {
      inviteMember(name: \$name, phone: \$phone, role: \$role, branchName: \$branchName) { $_memberFields }
    }
  ''');

  static final _roleDoc = gql('''
    mutation ChangeMemberRole(\$id: ID!, \$role: String!) {
      changeMemberRole(id: \$id, role: \$role) { $_memberFields }
    }
  ''');

  static final _activeDoc = gql('''
    mutation SetMemberActive(\$id: ID!, \$active: Boolean!) {
      setMemberActive(id: \$id, active: \$active) { $_memberFields }
    }
  ''');

  static final _resendDoc = gql(r'''
    mutation ResendInvite($id: ID!) { resendInvite(id: $id) { success } }
  ''');

  static final _cancelDoc = gql(r'''
    mutation CancelInvite($id: ID!) { cancelInvite(id: $id) { success } }
  ''');

  @override
  Future<Either<Failure, AgencyProfileDto>> getAgencyProfile() => _g.query<AgencyProfileDto>(
        QueryOptions<AgencyProfileDto>(
          document: _profileDoc,
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => AgencyProfileDto.fromJson(j['agencyProfile'] as Map<String, dynamic>),
        ),
      );

  @override
  Future<Either<Failure, MarginsOverviewDto>> getMargins() => _g.query<MarginsOverviewDto>(
        QueryOptions<MarginsOverviewDto>(
          document: _marginsDoc,
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => MarginsOverviewDto.fromJson(j['serviceMargins'] as Map<String, dynamic>),
        ),
      );

  @override
  Future<Either<Failure, MarginsOverviewDto>> saveMargins(Map<String, int> changes) =>
      _g.mutate<MarginsOverviewDto>(
        MutationOptions<MarginsOverviewDto>(
          document: _saveMarginsDoc,
          variables: {
            'changes': [
              for (final e in changes.entries) {'serviceId': e.key, 'value': e.value},
            ],
          },
          parserFn: (j) => MarginsOverviewDto.fromJson(j['saveServiceMargins'] as Map<String, dynamic>),
        ),
      );

  @override
  Future<Either<Failure, List<TeamMember>>> getTeam() => _g.query<List<TeamMember>>(
        QueryOptions<List<TeamMember>>(
          document: _teamDoc,
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => [
            for (final m in (j['teamMembers'] as List<dynamic>).cast<Map<String, dynamic>>()) teamMemberFromJson(m),
          ],
        ),
      );

  @override
  Future<Either<Failure, TeamMember>> inviteMember(InviteDraft d) => _g.mutate<TeamMember>(
        MutationOptions<TeamMember>(
          document: _inviteDoc,
          variables: {'name': d.name, 'phone': d.phone, 'role': roleWire(d.role), 'branchName': d.branchName},
          parserFn: (j) => teamMemberFromJson(j['inviteMember'] as Map<String, dynamic>),
        ),
      );

  @override
  Future<Either<Failure, TeamMember>> changeMemberRole(String id, TeamRole role) => _g.mutate<TeamMember>(
        MutationOptions<TeamMember>(
          document: _roleDoc,
          variables: {'id': id, 'role': roleWire(role)},
          parserFn: (j) => teamMemberFromJson(j['changeMemberRole'] as Map<String, dynamic>),
        ),
      );

  @override
  Future<Either<Failure, TeamMember>> setMemberActive(String id, {required bool active}) =>
      _g.mutate<TeamMember>(
        MutationOptions<TeamMember>(
          document: _activeDoc,
          variables: {'id': id, 'active': active},
          parserFn: (j) => teamMemberFromJson(j['setMemberActive'] as Map<String, dynamic>),
        ),
      );

  @override
  Future<Either<Failure, bool>> resendInvite(String id) => _g.mutate<bool>(
        MutationOptions<bool>(
          document: _resendDoc,
          variables: {'id': id},
          parserFn: (j) => (j['resendInvite'] as Map<String, dynamic>?)?['success'] as bool? ?? true,
        ),
      );

  @override
  Future<Either<Failure, bool>> cancelInvite(String id) => _g.mutate<bool>(
        MutationOptions<bool>(
          document: _cancelDoc,
          variables: {'id': id},
          parserFn: (j) => (j['cancelInvite'] as Map<String, dynamic>?)?['success'] as bool? ?? true,
        ),
      );
}
