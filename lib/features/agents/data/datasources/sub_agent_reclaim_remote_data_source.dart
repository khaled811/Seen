import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/utils/money.dart';
import '../../domain/repositories/sub_agent_reclaim_repository.dart';

/// `reclaimFromSubAgent` (`docs/api/mobile-api-reference.md`; permission
/// `wallet.topup.sub_agents`): the reverse of funding a sub-agency.
class SubAgentReclaimRemoteDataSource implements SubAgentReclaimRepository {
  SubAgentReclaimRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _reclaimDoc = gql(r'''
    mutation ReclaimFromSubAgent($subAgentId: ID!, $amount: Decimal!, $note: String!, $idempotencyKey: String) {
      reclaimFromSubAgent(subAgentId: $subAgentId, amount: $amount, note: $note, idempotencyKey: $idempotencyKey) { id }
    }
  ''');

  @override
  Future<Either<Failure, void>> reclaim({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  }) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _reclaimDoc,
        variables: {
          'subAgentId': subAgentId,
          'amount': MoneyParser.decimalStringFromCents(amountCents),
          'note': note ?? '',
          'idempotencyKey': idempotencyKey,
        },
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['reclaimFromSubAgent'] != null,
      )))
          .map((_) {});
}
