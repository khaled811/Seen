import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/missing_document.dart';
import '../../domain/repositories/missing_document_repository.dart';
import '../datasources/missing_document_remote_data_source.dart';

class MissingDocumentRepositoryImpl implements MissingDocumentRepository {
  const MissingDocumentRepositoryImpl({required MissingDocumentRemoteDataSource remote}) : _remote = remote;

  final MissingDocumentRemoteDataSource _remote;

  @override
  Future<Either<Failure, MissingDocumentRequest>> getMissingDocument(String requestId) =>
      _remote.getMissingDocument(requestId);

  @override
  Future<Either<Failure, void>> upload({
    required UploadTarget target,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  }) =>
      _remote.upload(target: target, document: document, onProgress: onProgress);
}
