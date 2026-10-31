import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/cancel_reason.dart';
import '../models/portal_requests_mapping.dart';
import '../models/request_detail_dto.dart';
import '../models/requests_page_dto.dart';

/// Raw GraphQL access for the requests feature (`docs/api/mobile-api-reference.md`,
/// "Services and requests"). Returns DTOs, never entities.
abstract interface class RequestsRemoteDataSource {
  Future<Either<Failure, RequestsPageDto>> getRequests({
    required String group,
    String? search,
    int offset = 0,
    int limit = 30,
  });

  Future<Either<Failure, RequestDetailDto>> getRequestDetail(String requestId);

  /// `cancelRequest`. The answer is only the new status, so the caller reloads
  /// the detail.
  Future<Either<Failure, void>> cancelRequest(String requestId, {CancelReason? reason});

  /// The API has no operation to nudge an approver: always a failure.
  Future<Either<Failure, void>> remindApprover(String requestId);
}

class RequestsRemoteDataSourceImpl implements RequestsRemoteDataSource {
  RequestsRemoteDataSourceImpl({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQLService = graphQLService,
        _language = language;

  final GraphQLService _graphQLService;
  final AppLanguage _language;

  /// Code of the failure returned for operations the API does not offer.
  static const String unsupportedCode = 'unsupported_operation';

  static const _cardFields = '''
    id
    referenceCode
    status
    serviceNameAr
    serviceNameEn
    travelerCount
    travelerNames
    amount
    deadlineAt
    createdAt
  ''';

  static final _requestsDocument = gql('''
    query PortalRequests(\$group: String!, \$search: String, \$limit: Int!, \$offset: Int!) {
      portalRequests(group: \$group, search: \$search, limit: \$limit, offset: \$offset) {
        items {
          $_cardFields
        }
        total
        hasMore
        filters {
          key
          count
        }
        attention {
          count
          soonestRemainingSeconds
        }
        hasAnyRequests
        canCreate
      }
    }
  ''');

  static final _trackingDocument = gql('''
    query PortalRequestTracking(\$id: ID!) {
      portalRequestTracking(id: \$id) {
        request {
          $_cardFields
        }
        filedAt
        feeTotal
        timeline {
          key
          state
          at
        }
        infoRequest {
          message
          deadlineAt
        }
        terminal {
          kind
          at
          reason
        }
        travelers {
          name
          status
        }
        outputs {
          fileId
          fileName
          contentType
          sizeBytes
        }
        actions {
          canCancel
          cancelReleasesFunds
          canAddDocuments
          canViewDocuments
          canDownloadResult
          canDecideApproval
          canContactSupport
        }
      }
    }
  ''');

  static final _cancelDocument = gql(r'''
    mutation CancelRequest($requestId: ID!, $reason: String!) {
      cancelRequest(requestId: $requestId, reason: $reason) {
        id
        status
      }
    }
  ''');

  @override
  Future<Either<Failure, RequestsPageDto>> getRequests({
    required String group,
    String? search,
    int offset = 0,
    int limit = 30,
  }) {
    final query = search?.trim();
    return _graphQLService.query<RequestsPageDto>(
      QueryOptions<RequestsPageDto>(
        document: _requestsDocument,
        variables: {
          'group': group,
          'search': query == null || query.isEmpty ? null : query,
          'limit': limit,
          'offset': offset,
        },
        parserFn: (json) =>
            PortalRequestsMapping.page(json['portalRequests'] as Map<String, dynamic>, _language),
      ),
    );
  }

  @override
  Future<Either<Failure, RequestDetailDto>> getRequestDetail(String requestId) async {
    // A list of zero or one: the service treats a null parse result as an error,
    // and "missing or outside the agency's scope" is a normal answer here.
    final result = await _graphQLService.query<List<RequestDetailDto>>(
      QueryOptions<List<RequestDetailDto>>(
        document: _trackingDocument,
        variables: {'id': requestId},
        parserFn: (json) {
          final tracking = json['portalRequestTracking'];
          return tracking == null
              ? const <RequestDetailDto>[]
              : [PortalRequestsMapping.tracking(tracking as Map<String, dynamic>, _language)];
        },
      ),
    );
    return result.flatMap(
      (found) => found.isEmpty
          ? const Left(ServerFailure('Request not found.', code: 'request_not_found'))
          : Right(found.single),
    );
  }

  @override
  Future<Either<Failure, void>> cancelRequest(String requestId, {CancelReason? reason}) async {
    final result = await _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _cancelDocument,
        // A free-text reason of 3-500 characters; the picked reason's name is readable text.
        variables: {'requestId': requestId, 'reason': (reason?.wire ?? 'other').toLowerCase()},
        parserFn: (json) => json['cancelRequest'] != null,
      ),
    );
    return result.flatMap((ok) => ok ? const Right(null) : const Left(ServerFailure('Cancellation was not confirmed.')));
  }

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async =>
      const Left(ServerFailure('An approver cannot be reminded.', code: unsupportedCode));
}
