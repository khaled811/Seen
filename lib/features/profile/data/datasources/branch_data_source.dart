import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/branch_repository.dart';

/// Raw GraphQL access to branches (`docs/api/mobile-api-reference.md`: `agentTree`,
/// `createBranch`, `updateUserRole`).
///
/// The API's `Branch` has an id, a name and a manager, nothing else: no parent,
/// no staff list, no counts. So the tree is flat, the people of a branch are its
/// manager, and the counts are absent (null), never invented.
class BranchRemoteDataSource implements BranchRepository {
  BranchRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  /// The caller's own agency (its id, from `portalAccount`) among the agencies of `agentTree`.
  static final _treeDoc = gql(r'''
    query Branches {
      portalAccount { agency { id } }
      agentTree { id branches { id name manager { id fullName } } }
    }
  ''');

  static final _agencyDoc = gql(r'''
    query BranchesAgency { portalAccount { agency { id } } }
  ''');

  static final _createDoc = gql(r'''
    mutation CreateBranch($agentId: ID!, $name: String!) {
      createBranch(agentId: $agentId, name: $name) { id name manager { id fullName } }
    }
  ''');

  static final _staffPositionDoc = gql(r'''
    query BranchMemberPosition { agentStaff { id agentPosition } }
  ''');

  static final _moveDoc = gql(r'''
    mutation MoveUserToBranch($userId: ID!, $position: String!, $branchId: ID) {
      updateUserRole(userId: $userId, position: $position, branchId: $branchId) { id }
    }
  ''');

  static Branch _branch(Map<String, dynamic> j) => Branch(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
      );

  Future<Either<Failure, List<Map<String, dynamic>>>> _ownBranches() => _graphQL.query<List<Map<String, dynamic>>>(
        QueryOptions<List<Map<String, dynamic>>>(
          document: _treeDoc,
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) {
            final agencyId = ((j['portalAccount'] as Map<String, dynamic>)['agency'] as Map<String, dynamic>)['id'];
            final own = (j['agentTree'] as List<dynamic>).cast<Map<String, dynamic>>().where((a) => a['id'] == agencyId);
            if (own.isEmpty) return const [];
            return (own.first['branches'] as List<dynamic>).cast<Map<String, dynamic>>();
          },
        ),
      );

  @override
  Future<Either<Failure, List<Branch>>> list() async => (await _ownBranches()).map((rows) => [for (final b in rows) _branch(b)]);

  @override
  Future<Either<Failure, List<BranchStaff>>> staff(String branchId) async => (await _ownBranches()).map((rows) {
        final manager = rows.where((b) => b['id'] == branchId).firstOrNull?['manager'] as Map<String, dynamic>?;
        if (manager == null) return const <BranchStaff>[];
        return [BranchStaff(id: manager['id'] as String, name: manager['fullName'] as String? ?? '', role: TeamRole.branchManager)];
      });

  @override
  Future<Either<Failure, Branch>> create(String name) async {
    final agency = await _graphQL.query<String>(
      QueryOptions<String>(
        document: _agencyDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => ((j['portalAccount'] as Map<String, dynamic>)['agency'] as Map<String, dynamic>)['id'] as String,
      ),
    );
    if (agency case Left(:final value)) return Left(value);
    return _graphQL.mutate<Branch>(MutationOptions<Branch>(
      document: _createDoc,
      variables: {'agentId': (agency as Right<Failure, String>).value, 'name': name},
      parserFn: (j) => _branch(j['createBranch'] as Map<String, dynamic>),
    ));
  }

  /// `updateUserRole` keeps the position and sets the branch: the position is read
  /// first because the operation needs one.
  @override
  Future<Either<Failure, void>> assign({required String memberId, required String branchId}) async {
    final staff = await _graphQL.query<Map<String, String?>>(
      QueryOptions<Map<String, String?>>(
        document: _staffPositionDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => {
          for (final u in (j['agentStaff'] as List<dynamic>).cast<Map<String, dynamic>>()) u['id'] as String: u['agentPosition'] as String?,
        },
      ),
    );
    if (staff case Left(:final value)) return Left(value);
    final positions = (staff as Right<Failure, Map<String, String?>>).value;
    final position = positions[memberId];
    if (position == null) return const Left(ServerFailure('User not found.', code: 'not_found'));
    final moved = await _graphQL.mutate<bool>(MutationOptions<bool>(
      document: _moveDoc,
      variables: {'userId': memberId, 'position': position, 'branchId': branchId},
      parserFn: (j) => j['updateUserRole'] != null,
    ));
    return moved.map((_) {});
  }
}
