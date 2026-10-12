import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
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

  Future<Either<Failure, RequestDetailDto>> cancelRequest(String requestId);
}

class RequestsRemoteDataSourceImpl implements RequestsRemoteDataSource {
  RequestsRemoteDataSourceImpl({required GraphQLService graphQLService})
      : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static const _travelerAndTimelineFields = r'''
    travelers { name passportNumber status }
    timeline { status occurredAt note }
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

  static final _cancelRequestDocument = gql('''
    mutation CancelRequest(\$requestId: ID!) {
      cancelRequest(requestId: \$requestId) {
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
  Future<Either<Failure, RequestDetailDto>> cancelRequest(String requestId) {
    return _graphQLService.mutate<RequestDetailDto>(
      MutationOptions<RequestDetailDto>(
        document: _cancelRequestDocument,
        variables: {'requestId': requestId},
        parserFn: (json) =>
            RequestDetailDto.fromJson(json['cancelRequest'] as Map<String, dynamic>),
      ),
    );
  }
}
