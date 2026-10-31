import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/file_upload_client.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/missing_document.dart';
import '../models/missing_document_dto.dart';

/// Reads what an "info required" request asks for and sends the document
/// (`POST /files/upload/`, `kind=document`, contract 8.1).
abstract interface class MissingDocumentRemoteDataSource {
  Future<Either<Failure, MissingDocumentRequest>> getMissingDocument(String requestId);

  Future<Either<Failure, void>> upload({
    required UploadTarget target,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  });
}

class MissingDocumentRemoteDataSourceImpl implements MissingDocumentRemoteDataSource {
  MissingDocumentRemoteDataSourceImpl({
    required GraphQLService graphQLService,
    required FileUploadClient uploads,
    required AppLanguage language,
  })  : _graphQLService = graphQLService,
        _uploads = uploads,
        _language = language;

  final GraphQLService _graphQLService;
  final FileUploadClient _uploads;
  final AppLanguage _language;

  static final _queryDocument = gql(r'''
    query MissingDocumentRequest($requestId: ID!) {
      portalRequestTracking(id: $requestId) {
        request { id referenceCode }
        infoRequest { message deadlineAt remainingSeconds }
        travelers { id index name nameMasked }
      }
      request(id: $requestId) {
        serviceType { documents { id labelAr labelEn required } }
        travelers { id documents { documentRequirement { id } } }
      }
    }
  ''');

  @override
  Future<Either<Failure, MissingDocumentRequest>> getMissingDocument(String requestId) async {
    final result = await _graphQLService.query<MissingDocumentRequest?>(QueryOptions<MissingDocumentRequest?>(
      document: _queryDocument,
      variables: {'requestId': requestId},
      fetchPolicy: FetchPolicy.networkOnly,
      parserFn: (json) => MissingDocumentDto.parse(json, _language),
    ));
    return result.flatMap(
      (request) => request == null
          // Not asking for anything (no info request, not found, or no document to attach).
          ? const Left(ServerFailure('No information is requested for this request.', code: 'not_info_required'))
          : Right(request),
    );
  }

  @override
  Future<Either<Failure, void>> upload({
    required UploadTarget target,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  }) async {
    final result = await _uploads.upload(
      kind: 'document',
      path: document.path,
      fileName: document.fileName,
      fields: {'travelerId': target.travelerId, 'documentRequirementId': target.requirementId},
      onProgress: onProgress,
    );
    return result.map((_) {});
  }
}
