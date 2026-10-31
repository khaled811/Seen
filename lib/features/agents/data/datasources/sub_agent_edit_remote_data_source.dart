import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/repositories/sub_agent_edit_repository.dart';

/// `updateAgentProfile` (`docs/api/mobile-api-reference.md`; permission `agent.create_sub_agent`,
/// a main agent over its own sub-agency).
class SubAgentEditRemoteDataSource implements SubAgentEditRepository {
  SubAgentEditRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _doc = gql(r'''
    mutation UpdateAgentProfile($agentId: ID!, $name: String, $ownerFullName: String, $ownerEmail: String) {
      updateAgentProfile(agentId: $agentId, name: $name, ownerFullName: $ownerFullName, ownerEmail: $ownerEmail) { id name }
    }
  ''');

  @override
  Future<Either<Failure, void>> update({required String agentId, String? name, String? ownerFullName, String? ownerEmail}) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _doc,
        variables: {'agentId': agentId, 'name': name, 'ownerFullName': ownerFullName, 'ownerEmail': ownerEmail},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['updateAgentProfile'] != null,
      )))
          .map((_) {});
}
