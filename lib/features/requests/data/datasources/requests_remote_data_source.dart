import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/cancel_reason.dart';
import '../models/request_detail_dto.dart';
import '../models/request_summary_dto.dart';

/// Raw GraphQL access for the requests feature. Returns DTOs, never entities.
///
/// TODO(backend-contract): documents below encode a placeholder schema
/// (query/mutation names, argument names, response fields). Update once the
/// real Seen Booking GraphQL schema is confirmed — see the matching TODOs
/// in the DTO files.
abstract interface class RequestsRemoteDataSource {
  Future<Either<Failure, List<RequestSummaryDto>>> getRequests();

  Future<Either<Failure, RequestDetailDto>> getRequestDetail(String requestId);

  Future<Either<Failure, RequestDetailDto>> cancelRequest(String requestId, {CancelReason? reason});

  /// Nudges the approver of a request waiting on approval (Figma REQ-06 / 07).
  Future<Either<Failure, void>> remindApprover(String requestId);
}

class RequestsRemoteDataSourceImpl implements RequestsRemoteDataSource {
  RequestsRemoteDataSourceImpl({required GraphQLService graphQLService})
      : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static const _travelerAndTimelineFields = r'''
    travelers { name passportNumber status documents { name url status } }
    timeline { status occurredAt note }
    approval { kind approverName typicalWaitMinutes thresholdAmount }
    rejectionReason
    cancellation { cancelledBy cancelledAt reason code }
    refundedAmount
  ''';

  static final _requestsDocument = gql(r'''
    query Requests {
      requests {
        id
        referenceId
        serviceName
        travelerCount
        totalPriceAmount
        status
        submittedAt
        slaDeadline
        travelerNames
      }
    }
  ''');

  static final _requestDetailDocument = gql('''
    query RequestDetail(\$requestId: ID!) {
      requestDetail(requestId: \$requestId) {
        id
        referenceId
        serviceName
        status
        totalPriceAmount
        submittedAt
        slaDeadline
        outputDocumentUrl
        $_travelerAndTimelineFields
      }
    }
  ''');

  // TODO(backend-contract): `reason` is a placeholder argument
  // (docs/BACKEND_MIGRATION_GAPS.md, section 21).
  static final _cancelRequestDocument = gql('''
    mutation CancelRequest(\$requestId: ID!, \$reason: CancelReason) {
      cancelRequest(requestId: \$requestId, reason: \$reason) {
        id
        referenceId
        serviceName
        status
        totalPriceAmount
        submittedAt
        slaDeadline
        outputDocumentUrl
        $_travelerAndTimelineFields
      }
    }
  ''');

  @override
  Future<Either<Failure, List<RequestSummaryDto>>> getRequests() {
    return _graphQLService.query<List<RequestSummaryDto>>(
      QueryOptions<List<RequestSummaryDto>>(
        document: _requestsDocument,
        parserFn: (json) => (json['requests'] as List<dynamic>)
            .map((e) => RequestSummaryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, RequestDetailDto>> getRequestDetail(String requestId) {
    return _graphQLService.query<RequestDetailDto>(
      QueryOptions<RequestDetailDto>(
        document: _requestDetailDocument,
        variables: {'requestId': requestId},
        parserFn: (json) =>
            RequestDetailDto.fromJson(json['requestDetail'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, RequestDetailDto>> cancelRequest(String requestId, {CancelReason? reason}) {
    return _graphQLService.mutate<RequestDetailDto>(
      MutationOptions<RequestDetailDto>(
        document: _cancelRequestDocument,
        variables: {'requestId': requestId, 'reason': reason?.wire},
        parserFn: (json) =>
            RequestDetailDto.fromJson(json['cancelRequest'] as Map<String, dynamic>),
      ),
    );
  }

  // TODO(backend-contract): placeholder (docs/BACKEND_MIGRATION_GAPS.md, section 20).
  static final _remindDocument = gql(r'''
    mutation RemindApprover($requestId: ID!) {
      remindApprover(requestId: $requestId) { success }
    }
  ''');

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async {
    final result = await _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _remindDocument,
        variables: {'requestId': requestId},
        parserFn: (json) => (json['remindApprover'] as Map<String, dynamic>)['success'] as bool? ?? false,
      ),
    );
    return result.flatMap((ok) => ok ? const Right(null) : const Left(ServerFailure('Reminder was not sent.')));
  }
}
