import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/agency_profile.dart';
import '../../domain/entities/service_margin.dart';
import '../../domain/entities/team_member.dart';
import '../../../../core/utils/money.dart';
import '../models/profile_dtos.dart';

/// Raw GraphQL access for agency details, margins and the team
/// (`docs/api/mobile-api-reference.md`: `portalAccount`, `agentStaff`,
/// `createStaffUser`, `updateUserRole`).
///
/// What the contract does not offer is answered with `unsupported_operation`
/// and never sent: disabling a user, resending or cancelling an invitation (there
/// are no invitations: the owner creates the user with a password).
///
/// Margins are per sub-agency and service (`setAgentServiceEnablement`): a fixed
/// price or a percentage, never both. The app shows a fixed one as the amount added
/// to the agency's own price (`ServiceType.myPrice`).
abstract interface class ProfileRemoteDataSource {
  Future<Either<Failure, AgencyProfile>> getAgencyProfile();

  Future<Either<Failure, MarginsOverview>> getMargins(String agentId);

  /// One `setAgentServiceEnablement` per changed service, in order, stopping at the
  /// first refusal (a request may carry at most 3 mutations). Returns the margins as
  /// the server has them afterwards.
  Future<Either<Failure, MarginsOverview>> saveMargins(String agentId, Map<String, int> changes);

  Future<Either<Failure, List<TeamMember>>> getTeam();

  Future<Either<Failure, TeamMember>> inviteMember(InviteDraft draft);

  Future<Either<Failure, TeamMember>> changeMemberRole(String id, TeamRole role);

}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl({required GraphQLService graphQLService, required AppLanguage language})
      : _g = graphQLService,
        _language = language;

  final GraphQLService _g;
  final AppLanguage _language;

  static final _profileDoc = gql(r'''
    query AgencyProfile {
      portalAccount {
        agency { name status isVerified city licenseNumber }
        user { fullName position }
      }
    }
  ''');

  static final _marginsDoc = gql(r'''
    query AgentMargins($agentId: ID!) {
      availableServices { id nameAr nameEn code myPrice priceForAgent(agentId: $agentId) }
      agentTree(rootAgentId: $agentId) { id serviceEnablements { enabled overridePrice markupPercent serviceType { id } } }
    }
  ''');

  static final _setMarginDoc = gql(r'''
    mutation SetAgentMargin($agentId: ID!, $serviceTypeId: ID!, $enabled: Boolean!, $overridePrice: Decimal, $markupPercent: Decimal) {
      setAgentServiceEnablement(agentId: $agentId, serviceTypeId: $serviceTypeId, enabled: $enabled, overridePrice: $overridePrice, markupPercent: $markupPercent)
    }
  ''');

  static final _teamDoc = gql(r'''
    query TeamMembers {
      agentStaff { id fullName agentPosition isActive }
    }
  ''');

  static final _createStaffDoc = gql(r'''
    mutation CreateStaffUser($input: StaffUserInput!) {
      createStaffUser(input: $input) { id fullName agentPosition isActive }
    }
  ''');

  static final _roleDoc = gql(r'''
    mutation UpdateUserRole($userId: ID!, $position: String!) {
      updateUserRole(userId: $userId, position: $position) { id fullName agentPosition isActive }
    }
  ''');

  @override
  Future<Either<Failure, AgencyProfile>> getAgencyProfile() => _g.query<AgencyProfile>(
        QueryOptions<AgencyProfile>(
          document: _profileDoc,
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => agencyProfileFromPortal(j['portalAccount'] as Map<String, dynamic>),
        ),
      );

  @override
  Future<Either<Failure, MarginsOverview>> getMargins(String agentId) => _g.query<MarginsOverview>(
        QueryOptions<MarginsOverview>(
          document: _marginsDoc,
          variables: {'agentId': agentId},
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => marginsFromJson(j, agentId, _language),
        ),
      );

  @override
  Future<Either<Failure, MarginsOverview>> saveMargins(String agentId, Map<String, int> changes) async {
    final current = await getMargins(agentId);
    if (current case Left(:final value)) return Left(value);
    final byId = {for (final m in (current as Right<Failure, MarginsOverview>).value.margins) m.serviceId: m};
    for (final change in changes.entries) {
      final margin = byId[change.key];
      // Only a service already enabled for that agency is changed here: a margin edit never switches one on.
      if (margin == null || !margin.editable) return const Left(ServerFailure('Service not enabled.', code: 'margin_invalid'));
      final percent = margin.kind == MarginKind.percent;
      final base = margin.basePriceCents;
      if (!percent && base == null) return const Left(ServerFailure('No base price.', code: 'margin_invalid'));
      final done = await _g.mutate<bool>(
        MutationOptions<bool>(
          document: _setMarginDoc,
          variables: {
            'agentId': agentId,
            'serviceTypeId': change.key,
            'enabled': true,
            'overridePrice': percent ? null : MoneyParser.decimalStringFromCents(base! + change.value),
            'markupPercent': percent ? MoneyParser.decimalStringFromCents(change.value) : null,
          },
          fetchPolicy: FetchPolicy.noCache,
          parserFn: (j) => j['setAgentServiceEnablement'] == true,
        ),
      );
      if (done case Left(:final value)) return Left(value);
      if (done case Right(value: false)) return const Left(ServerFailure('Margin not saved.', code: 'margin_invalid'));
    }
    return getMargins(agentId);
  }

  @override
  Future<Either<Failure, List<TeamMember>>> getTeam() => _g.query<List<TeamMember>>(
        QueryOptions<List<TeamMember>>(
          document: _teamDoc,
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => [
            for (final m in (j['agentStaff'] as List<dynamic>).cast<Map<String, dynamic>>()) teamMemberFromUser(m),
          ],
        ),
      );

  @override
  Future<Either<Failure, TeamMember>> inviteMember(InviteDraft d) => _g.mutate<TeamMember>(
        MutationOptions<TeamMember>(
          document: _createStaffDoc,
          variables: {
            'input': {
              'email': d.email,
              'fullName': d.name,
              'password': d.password,
              'position': positionOf(d.role),
              if (d.branchId != null) 'branchId': d.branchId,
            },
          },
          parserFn: (j) => teamMemberFromUser(j['createStaffUser'] as Map<String, dynamic>, branchName: d.branchName),
        ),
      );

  @override
  Future<Either<Failure, TeamMember>> changeMemberRole(String id, TeamRole role) => _g.mutate<TeamMember>(
        MutationOptions<TeamMember>(
          document: _roleDoc,
          variables: {'userId': id, 'position': positionOf(role)},
          parserFn: (j) => teamMemberFromUser(j['updateUserRole'] as Map<String, dynamic>),
        ),
      );

}
