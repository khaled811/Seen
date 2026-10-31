import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/new_sub_agent.dart';
import '../models/sub_agent_dto.dart';
import '../models/sub_agent_profile_dto.dart';
import '../models/sub_agent_request_summary_dto.dart';

/// Raw GraphQL access for the agents feature (`docs/api/mobile-api-reference.md`,
/// "Agency team and sub-agents"). Returns DTOs, never entities.
abstract interface class AgentsRemoteDataSource {
  Future<Either<Failure, List<SubAgentDto>>> getSubAgents();

  Future<Either<Failure, List<SubAgentRequestSummaryDto>>> getPendingApprovalRequests();

  /// Returns `true` on success. Not `void`: `GraphQLService` treats a `null`
  /// parsed result as an empty-response failure.
  Future<Either<Failure, bool>> approveRequest(String requestId);

  Future<Either<Failure, bool>> rejectRequest(String requestId, {required String reason});

  /// `topUpSubAgent`: the amount moves from the caller's own wallet. [idempotencyKey]
  /// makes a retry of the same action safe.
  Future<Either<Failure, bool>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  });

  Future<Either<Failure, SubAgentDto>> createSubAgent(NewSubAgent newSubAgent);

  Future<Either<Failure, SubAgentProfileDto>> getSubAgentProfile(String subAgentId);

  /// `setAgentStatus`: `active` or `suspended` (a pending agency becomes active).
  Future<Either<Failure, bool>> setSubAgentActive({required String subAgentId, required bool active});
}

class AgentsRemoteDataSourceImpl implements AgentsRemoteDataSource {
  AgentsRemoteDataSourceImpl({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQLService = graphQLService,
        _language = language;

  final GraphQLService _graphQLService;
  final AppLanguage _language;

  /// How many sub-agencies one read asks for (the contract's `limit` default is 50).
  static const int pageSize = 200;

  /// How many statement rows / requests the profile shows.
  static const int profileRows = 20;

  static final _subAgentsDocument = gql('''
    query SubAgents(\$limit: Int!) {
      portalAgents(status: "all", limit: \$limit) {
        items { ${SubAgentDto.portalFields} }
      }
    }
  ''');

  static final _pendingApprovalRequestsDocument = gql('''
    query PendingAgentApprovalRequests {
      requests(status: "pending_agent_approval", limit: 100) { ${SubAgentRequestSummaryDto.requestFields} }
    }
  ''');

  static final _decideDocument = gql(r'''
    mutation DecideMainAgentApproval($requestId: ID!, $approve: Boolean!, $note: String!) {
      decideMainAgentApproval(requestId: $requestId, approve: $approve, note: $note) { id }
    }
  ''');

  static final _topUpDocument = gql(r'''
    mutation TopUpSubAgent($subAgentId: ID!, $amount: Decimal!, $note: String!, $idempotencyKey: String) {
      topUpSubAgent(subAgentId: $subAgentId, amount: $amount, note: $note, idempotencyKey: $idempotencyKey) { id }
    }
  ''');

  static final _createDocument = gql(r'''
    mutation CreateSubAgent($input: SubAgentInput!) {
      createSubAgent(input: $input) { id name status }
    }
  ''');

  static final _setStatusDocument = gql(r'''
    mutation SetAgentStatus($agentId: ID!, $status: String!) {
      setAgentStatus(agentId: $agentId, status: $status) { id status }
    }
  ''');

  static final _profileDocument = gql('''
    query SubAgentProfile(\$limit: Int!) {
      portalAgents(status: "all", limit: \$limit) {
        items { ${SubAgentDto.portalFields} }
      }
    }
  ''');

  static final _statementDocument = gql('''
    query SubAgentStatement(\$agentId: ID!, \$limit: Int!) {
      portalWallet(agentId: \$agentId, filter: "all", limit: \$limit) {
        statement { ${LedgerEntryDto.statementFields} }
      }
    }
  ''');

  static final _agentRequestsDocument = gql('''
    query SubAgentRequests(\$agentId: ID!, \$limit: Int!) {
      requests(agentId: \$agentId, limit: \$limit) { ${AgentRequestDto.requestFields} }
    }
  ''');

  @override
  Future<Either<Failure, List<SubAgentDto>>> getSubAgents() {
    return _graphQLService.query<List<SubAgentDto>>(
      QueryOptions<List<SubAgentDto>>(
        document: _subAgentsDocument,
        variables: const {'limit': pageSize},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: _parseAgents,
      ),
    );
  }

  static List<SubAgentDto> _parseAgents(Map<String, dynamic> json) {
    final items = (json['portalAgents'] as Map<String, dynamic>)['items'] as List<dynamic>;
    return [for (final e in items) SubAgentDto.fromPortalJson(e as Map<String, dynamic>)];
  }

  @override
  Future<Either<Failure, List<SubAgentRequestSummaryDto>>> getPendingApprovalRequests() {
    return _graphQLService.query<List<SubAgentRequestSummaryDto>>(
      QueryOptions<List<SubAgentRequestSummaryDto>>(
        document: _pendingApprovalRequestsDocument,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) => [
          for (final e in json['requests'] as List<dynamic>)
            SubAgentRequestSummaryDto.fromJson(e as Map<String, dynamic>, _language),
        ],
      ),
    );
  }

  Future<Either<Failure, bool>> _decide(String requestId, {required bool approve, String note = ''}) {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _decideDocument,
        variables: {'requestId': requestId, 'approve': approve, 'note': note},
        parserFn: (json) => json['decideMainAgentApproval'] != null,
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> approveRequest(String requestId) => _decide(requestId, approve: true);

  @override
  Future<Either<Failure, bool>> rejectRequest(String requestId, {required String reason}) =>
      _decide(requestId, approve: false, note: reason);

  @override
  Future<Either<Failure, bool>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  }) {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _topUpDocument,
        variables: {
          'subAgentId': subAgentId,
          'amount': MoneyParser.decimalStringFromCents(amountCents),
          'note': note ?? '',
          'idempotencyKey': idempotencyKey,
        },
        parserFn: (json) => json['topUpSubAgent'] != null,
      ),
    );
  }

  @override
  Future<Either<Failure, SubAgentDto>> createSubAgent(NewSubAgent newSubAgent) {
    return _graphQLService.mutate<SubAgentDto>(
      MutationOptions<SubAgentDto>(
        document: _createDocument,
        variables: {
          'input': {
            'name': newSubAgent.agencyName,
            'ownerFullName': newSubAgent.managerName,
            'ownerEmail': newSubAgent.email,
            'ownerPassword': newSubAgent.password,
          },
        },
        parserFn: (json) {
          final agent = json['createSubAgent'] as Map<String, dynamic>;
          return SubAgentDto(
            id: agent['id'] as String,
            name: agent['name'] as String,
            status: agent['status'] as String? ?? '',
            city: '',
            balanceAmount: null,
          );
        },
      ),
    );
  }

  @override
  Future<Either<Failure, SubAgentProfileDto>> getSubAgentProfile(String subAgentId) async {
    final agents = await _graphQLService.query<List<SubAgentDto>>(
      QueryOptions<List<SubAgentDto>>(
        document: _profileDocument,
        variables: const {'limit': pageSize},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: _parseAgents,
      ),
    );
    if (agents case Left(:final value)) return Left(value);
    final matches = (agents as Right<Failure, List<SubAgentDto>>).value.where((a) => a.id == subAgentId);
    // A sub-agency outside the caller's own looks nonexistent to the server too.
    if (matches.isEmpty) return const Left(ServerFailure('Agency not found.', code: 'not_found'));

    // The statement and the requests are extra sections: when the server refuses
    // them (a permission the user does not hold) the profile shows without them.
    final statement = await _graphQLService.query<List<LedgerEntryDto>>(
      QueryOptions<List<LedgerEntryDto>>(
        document: _statementDocument,
        variables: {'agentId': subAgentId, 'limit': profileRows},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) => [
          for (final e in (json['portalWallet'] as Map<String, dynamic>)['statement'] as List<dynamic>)
            LedgerEntryDto.fromJson(e as Map<String, dynamic>),
        ],
      ),
    );
    final requests = await _graphQLService.query<List<AgentRequestDto>>(
      QueryOptions<List<AgentRequestDto>>(
        document: _agentRequestsDocument,
        variables: {'agentId': subAgentId, 'limit': profileRows},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) => [
          for (final e in json['requests'] as List<dynamic>) AgentRequestDto.fromJson(e as Map<String, dynamic>, _language),
        ],
      ),
    );
    // A dropped connection fails the whole profile (nothing half-shown); a refusal does not.
    for (final extra in [statement, requests]) {
      if (extra case Left(value: final NetworkFailure failure)) return Left(failure);
      if (extra case Left(value: final UnauthorizedFailure failure)) return Left(failure);
    }
    return Right(SubAgentProfileDto(
      agent: matches.first,
      ledger: statement.getOrElse((_) => const []),
      requests: requests.getOrElse((_) => const []),
    ));
  }

  @override
  Future<Either<Failure, bool>> setSubAgentActive({required String subAgentId, required bool active}) {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _setStatusDocument,
        variables: {'agentId': subAgentId, 'status': active ? 'active' : 'suspended'},
        parserFn: (json) => json['setAgentStatus'] != null,
      ),
    );
  }
}
