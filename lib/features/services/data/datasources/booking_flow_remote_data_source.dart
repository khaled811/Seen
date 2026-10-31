import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/file_upload_client.dart';
import '../../domain/entities/booking_document.dart';
import '../../domain/entities/draft_review.dart';
import '../../domain/entities/field_value_input.dart';
import '../../domain/entities/service_booking_result.dart';
import '../../../../core/network/graphql_service.dart';
import '../models/draft_review_dto.dart';
import '../models/submitted_request_dto.dart';

/// The server calls of filing a request (contract 10.2). DTO level: the
/// repository maps to entities.
abstract interface class BookingFlowRemoteDataSource {
  Future<Either<Failure, String>> createDraft(String serviceTypeId);

  Future<Either<Failure, List<String>>> addTravelers(String requestId, List<List<FieldValueInput>> travelers);

  Future<Either<Failure, void>> uploadDocument(BookingDocumentUpload upload);

  Future<Either<Failure, DraftReview>> reviewDraft(String requestId);

  Future<Either<Failure, ServiceBookingResult>> submit(String requestId);
}

class BookingFlowRemoteDataSourceImpl implements BookingFlowRemoteDataSource {
  BookingFlowRemoteDataSourceImpl({
    required GraphQLService graphQLService,
    required FileUploadClient uploads,
    required AppLanguage language,
  })  : _graphQLService = graphQLService,
        _uploads = uploads,
        _language = language;

  final GraphQLService _graphQLService;
  final FileUploadClient _uploads;
  final AppLanguage _language;

  static final _createDraftDocument = gql(r'''
    mutation CreateDraftRequest($serviceTypeId: ID!) {
      createDraftRequest(serviceTypeId: $serviceTypeId) { id status }
    }
  ''');

  static final _batchAddDocument = gql(r'''
    mutation BatchAddTravelers($requestId: ID!, $travelers: [BatchTravelerInput!]!) {
      batchAddTravelers(requestId: $requestId, travelers: $travelers) { id }
    }
  ''');

  static final _reviewDocument = gql(r'''
    query PortalDraftReview($requestId: ID!) {
      portalDraftReview(requestId: $requestId) {
        requestId
        status
        service { id nameAr nameEn }
        travelers { id index name nameMasked passportNumber documentsCount }
        quote {
          currency
          unitPrice
          travelerCount
          total
          balance
          availableAfter
          creditLimit
          fundsSufficient
          holdDeferred
          slaHours
        }
        errors
        violations
        canSubmit
      }
    }
  ''');

  static final _submitDocument = gql(r'''
    mutation SubmitRequest($requestId: ID!) {
      submitRequest(requestId: $requestId) { id referenceCode status }
    }
  ''');

  @override
  Future<Either<Failure, String>> createDraft(String serviceTypeId) {
    return _graphQLService.mutate<String>(
      MutationOptions<String>(
        document: _createDraftDocument,
        variables: {'serviceTypeId': serviceTypeId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (json) => (json['createDraftRequest'] as Map<String, dynamic>)['id'].toString(),
      ),
    );
  }

  @override
  Future<Either<Failure, List<String>>> addTravelers(String requestId, List<List<FieldValueInput>> travelers) {
    return _graphQLService.mutate<List<String>>(
      MutationOptions<List<String>>(
        document: _batchAddDocument,
        variables: {
          'requestId': requestId,
          'travelers': [
            for (final fields in travelers)
              {
                'fieldValues': [
                  for (final f in fields) {'fieldDefinitionId': f.fieldDefinitionId, 'value': f.value},
                ],
              },
          ],
        },
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (json) => [
          for (final t in json['batchAddTravelers'] as List<dynamic>) (t as Map<String, dynamic>)['id'].toString(),
        ],
      ),
    );
  }

  @override
  Future<Either<Failure, void>> uploadDocument(BookingDocumentUpload upload) async {
    final result = await _uploads.upload(
      kind: 'document',
      path: upload.document.path,
      fileName: upload.document.fileName,
      fields: {'travelerId': upload.travelerId, 'documentRequirementId': upload.requirementId},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, DraftReview>> reviewDraft(String requestId) {
    return _graphQLService.query<DraftReview>(
      QueryOptions<DraftReview>(
        document: _reviewDocument,
        variables: {'requestId': requestId},
        // A quote is only worth something fresh.
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) => DraftReviewDto.parse(json['portalDraftReview'] as Map<String, dynamic>, _language),
      ),
    );
  }

  @override
  Future<Either<Failure, ServiceBookingResult>> submit(String requestId) {
    return _graphQLService.mutate<ServiceBookingResult>(
      MutationOptions<ServiceBookingResult>(
        document: _submitDocument,
        variables: {'requestId': requestId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (json) => SubmittedRequestDto.parse(json['submitRequest'] as Map<String, dynamic>),
      ),
    );
  }
}
