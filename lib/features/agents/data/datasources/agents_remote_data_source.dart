import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/utils/money.dart';
import '../models/sub_agent_dto.dart';
import '../models/sub_agent_request_summary_dto.dart';

/// Raw GraphQL access for the agents feature. Returns DTOs, never entities.
///
/// TODO(backend-contract): documents below encode a placeholder schema
/// (query/mutation names, argument names, response fields). Update once the
/// real Seen Booking GraphQL schema is confirmed — see the matching TODOs
/// in the DTO files.
abstract interface class AgentsRemoteDataSource {
  Future<Either<Failure, List<SubAgentDto>>> getSubAgents();

  Future<Either<Failure, List<SubAgentRequestSummaryDto>>> getPendingApprovalRequests();

  /// Returns `true` on success. Not `void` — `GraphQLService` treats a
  /// `null` parsed result as an empty-response failure, so the parser must
  /// produce a real, non-null value even for a mutation with no
  /// interesting payload.
  Future<Either<Failure, bool>> approveRequest(String requestId);

  Future<Either<Failure, bool>> rejectRequest(String requestId, {required String reason});

  Future<Either<Failure, SubAgentDto>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
  });
}

class AgentsRemoteDataSourceImpl implements AgentsRemoteDataSource {
  AgentsRemoteDataSourceImpl({required GraphQLService graphQLService})
      : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static final _subAgentsDocument = gql(r'''
    query SubAgents {
      subAgents {
        id
        name
        code
        balanceAmount
        isActive
        marginPercent
      }
    }
  ''');

  static final _pendingApprovalRequestsDocument = gql(r'''
    query PendingAgentApprovalRequests {
      pendingAgentApprovalRequests {
        id
        referenceId
        subAgentName
        serviceName
        travelerCount
        totalPriceAmount
        submittedAt
      }
    }
  ''');

  static final _approveRequestDocument = gql(r'''
    mutation ApproveSubAgentRequest($requestId: ID!) {
      approveSubAgentRequest(requestId: $requestId) {
        success
      }
    }
  ''');

  static final _rejectRequestDocument = gql(r'''
    mutation RejectSubAgentRequest($requestId: ID!, $reason: String!) {
      rejectSubAgentRequest(requestId: $requestId, reason: $reason) {
        success
      }
    }
  ''');

  static final _fundSubAgentWalletDocument = gql(r'''
    mutation FundSubAgentWallet($subAgentId: ID!, $amount: String!) {
      fundSubAgentWallet(subAgentId: $subAgentId, amount: $amount) {
        id
        name
        code
        balanceAmount
        isActive
        marginPercent
      }
    }
  ''');

  @override
  Future<Either<Failure, List<SubAgentDto>>> getSubAgents() {
    return _graphQLService.query<List<SubAgentDto>>(
      QueryOptions<List<SubAgentDto>>(
        document: _subAgentsDocument,
        parserFn: (json) => (json['subAgents'] as List<dynamic>)
            .map((e) => SubAgentDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, List<SubAgentRequestSummaryDto>>> getPendingApprovalRequests() {
    return _graphQLService.query<List<SubAgentRequestSummaryDto>>(
      QueryOptions<List<SubAgentRequestSummaryDto>>(
        document: _pendingApprovalRequestsDocument,
        parserFn: (json) => (json['pendingAgentApprovalRequests'] as List<dynamic>)
            .map((e) => SubAgentRequestSummaryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> approveRequest(String requestId) {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _approveRequestDocument,
        variables: {'requestId': requestId},
        parserFn: (json) =>
            (json['approveSubAgentRequest'] as Map<String, dynamic>?)?['success']
                as bool? ??
            true,
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> rejectRequest(String requestId, {required String reason}) {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _rejectRequestDocument,
        variables: {'requestId': requestId, 'reason': reason},
        parserFn: (json) =>
            (json['rejectSubAgentRequest'] as Map<String, dynamic>?)?['success']
                as bool? ??
            true,
      ),
    );
  }

  @override
  Future<Either<Failure, SubAgentDto>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
  }) {
    return _graphQLService.mutate<SubAgentDto>(
      MutationOptions<SubAgentDto>(
        document: _fundSubAgentWalletDocument,
        variables: {
          'subAgentId': subAgentId,
          'amount': MoneyParser.decimalStringFromCents(amountCents),
        },
        parserFn: (json) =>
            SubAgentDto.fromJson(json['fundSubAgentWallet'] as Map<String, dynamic>),
      ),
    );
  }
}
