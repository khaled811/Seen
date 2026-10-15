import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' show MultipartFile;

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/missing_document.dart';
import '../models/missing_document_dto.dart';

/// Raw GraphQL access for "upload the missing document".
///
/// TODO(backend-contract): `missingDocumentRequest` and `uploadMissingDocument`
/// (multipart GraphQL upload) are placeholders until the real schema exists
/// (docs/BACKEND_MIGRATION_GAPS.md, section 10). A multipart GraphQL call cannot
/// report byte progress; a pre-signed URL upload can.
abstract interface class MissingDocumentRemoteDataSource {
  Future<Either<Failure, MissingDocumentDto>> getMissingDocument(String requestId);

  Future<Either<Failure, void>> upload({
    required String requestId,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  });
}

class MissingDocumentRemoteDataSourceImpl implements MissingDocumentRemoteDataSource {
  MissingDocumentRemoteDataSourceImpl({required GraphQLService graphQLService}) : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static final _queryDocument = gql(r'''
    query MissingDocumentRequest($requestId: ID!) {
      missingDocumentRequest(requestId: $requestId) {
        requestId referenceId documentTitle travelerName reason deadline maxBytes allowedExtensions
      }
    }
  ''');

  static final _uploadDocument = gql(r'''
    mutation UploadMissingDocument($requestId: ID!, $file: Upload!) {
      uploadMissingDocument(requestId: $requestId, file: $file) { success }
    }
  ''');

  @override
  Future<Either<Failure, MissingDocumentDto>> getMissingDocument(String requestId) =>
      _graphQLService.query<MissingDocumentDto>(QueryOptions<MissingDocumentDto>(
        document: _queryDocument,
        variables: {'requestId': requestId},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) => MissingDocumentDto.fromJson(json['missingDocumentRequest'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, void>> upload({
    required String requestId,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  }) async {
    final file = await MultipartFile.fromPath('file', document.path, filename: document.fileName);
    final result = await _graphQLService.mutate<bool>(MutationOptions<bool>(
      document: _uploadDocument,
      variables: {'requestId': requestId, 'file': file},
      parserFn: (json) => (json['uploadMissingDocument'] as Map<String, dynamic>)['success'] as bool? ?? false,
    ));
    onProgress?.call(1);
    return result.flatMap((ok) => ok ? const Right(null) : const Left(ServerFailure('Document was not accepted.')));
  }
}
