import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/new_sub_agent.dart';
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
    String? note,
  });

  Future<Either<Failure, SubAgentDto>> createSubAgent(NewSubAgent newSubAgent);

  Future<Either<Failure, SubAgentDto>> updateCreditLimit({required String subAgentId, required int limitCents});
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
    mutation FundSubAgentWallet($subAgentId: ID!, $amount: String!, $note: String) {
      fundSubAgentWallet(subAgentId: $subAgentId, amount: $amount, note: $note) {
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
    String? note,
  }) {
    return _graphQLService.mutate<SubAgentDto>(
      MutationOptions<SubAgentDto>(
        document: _fundSubAgentWalletDocument,
        variables: {
          'subAgentId': subAgentId,
          'amount': MoneyParser.decimalStringFromCents(amountCents),
          if (note != null && note.isNotEmpty) 'note': note,
        },
        parserFn: (json) =>
            SubAgentDto.fromJson(json['fundSubAgentWallet'] as Map<String, dynamic>),
      ),
    );
  }

  // TODO(backend-contract): `createSubAgent` / `updateSubAgentCreditLimit` are
  // placeholders (docs/BACKEND_MIGRATION_GAPS.md, section 15).
  static final _createSubAgentDocument = gql(r'''
    mutation CreateSubAgent($input: CreateSubAgentInput!) {
      createSubAgent(input: $input) {
        id name code balanceAmount isActive marginPercent creditLimitAmount creditUsedAmount invitePending
      }
    }
  ''');

  static final _updateCreditLimitDocument = gql(r'''
    mutation UpdateSubAgentCreditLimit($subAgentId: ID!, $creditLimit: String!) {
      updateSubAgentCreditLimit(subAgentId: $subAgentId, creditLimit: $creditLimit) {
        id name code balanceAmount isActive marginPercent creditLimitAmount creditUsedAmount invitePending
      }
    }
  ''');

  @override
  Future<Either<Failure, SubAgentDto>> createSubAgent(NewSubAgent newSubAgent) {
    return _graphQLService.mutate<SubAgentDto>(
      MutationOptions<SubAgentDto>(
        document: _createSubAgentDocument,
        variables: {
          'input': {
            'agencyName': newSubAgent.agencyName,
            'managerName': newSubAgent.managerName,
            'phone': newSubAgent.phone,
            if (newSubAgent.email != null) 'email': newSubAgent.email,
            if (newSubAgent.marginPercent != null) 'marginPercent': newSubAgent.marginPercent,
            if (newSubAgent.creditLimitCents != null)
              'creditLimit': MoneyParser.decimalStringFromCents(newSubAgent.creditLimitCents!),
            'sendInvite': newSubAgent.sendInvite,
          },
        },
        parserFn: (json) => SubAgentDto.fromJson(json['createSubAgent'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, SubAgentDto>> updateCreditLimit({required String subAgentId, required int limitCents}) {
    return _graphQLService.mutate<SubAgentDto>(
      MutationOptions<SubAgentDto>(
        document: _updateCreditLimitDocument,
        variables: {'subAgentId': subAgentId, 'creditLimit': MoneyParser.decimalStringFromCents(limitCents)},
        parserFn: (json) => SubAgentDto.fromJson(json['updateSubAgentCreditLimit'] as Map<String, dynamic>),
      ),
    );
  }
}
