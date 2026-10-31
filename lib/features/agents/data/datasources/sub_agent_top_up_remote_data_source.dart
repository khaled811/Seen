import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sub_agent_top_up.dart';
import '../../domain/repositories/sub_agent_top_up_repository.dart';

/// `pendingSubAgentTopUps`, `approveSubAgentTopUp`, `rejectSubAgentTopUp`
/// (`docs/api/mobile-api-reference.md`; permission `wallet.topup.sub_agents`).
class SubAgentTopUpRemoteDataSource implements SubAgentTopUpRepository {
  SubAgentTopUpRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _pendingDoc = gql(r'''
    query PendingSubAgentTopUps {
      pendingSubAgentTopUps { id status amount note createdAt agent { name } }
    }
  ''');

  static final _approveDoc = gql(r'''
    mutation ApproveSubAgentTopUp($transactionId: ID!) {
      approveSubAgentTopUp(transactionId: $transactionId) { id status }
    }
  ''');

  static final _rejectDoc = gql(r'''
    mutation RejectSubAgentTopUp($transactionId: ID!, $note: String!) {
      rejectSubAgentTopUp(transactionId: $transactionId, note: $note) { id status }
    }
  ''');

  @override
  Future<Either<Failure, List<SubAgentTopUp>>> pending() => _graphQL.query<List<SubAgentTopUp>>(
        QueryOptions<List<SubAgentTopUp>>(
          document: _pendingDoc,
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => [
            for (final t in (j['pendingSubAgentTopUps'] as List<dynamic>).cast<Map<String, dynamic>>())
              // Only pending ones are offered for a decision, whatever else the server sends.
              if ((t['status'] as String? ?? 'pending') == 'pending')
                SubAgentTopUp(
                  id: t['id'] as String,
                  agentName: (t['agent'] as Map<String, dynamic>?)?['name'] as String? ?? '',
                  amountCents: MoneyParser.centsFromDecimalString(t['amount'] as String),
                  createdAt: DateTime.parse(t['createdAt'] as String).toLocal(),
                  note: t['note'] as String? ?? '',
                ),
          ],
        ),
      );

  @override
  Future<Either<Failure, void>> approve(String transactionId) async => (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _approveDoc,
        variables: {'transactionId': transactionId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['approveSubAgentTopUp'] != null,
      )))
          .map((_) {});

  @override
  Future<Either<Failure, void>> reject(String transactionId, {required String note}) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _rejectDoc,
        variables: {'transactionId': transactionId, 'note': note},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['rejectSubAgentTopUp'] != null,
      )))
          .map((_) {});
}
