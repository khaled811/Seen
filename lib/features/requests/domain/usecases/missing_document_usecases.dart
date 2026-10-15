import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/missing_document.dart';
import '../repositories/missing_document_repository.dart';
import '../services/document_picker.dart';

class GetMissingDocumentUseCase {
  const GetMissingDocumentUseCase(this._repository);
  final MissingDocumentRepository _repository;

  Future<Either<Failure, MissingDocumentRequest>> call(String requestId) => _repository.getMissingDocument(requestId);
}

class UploadMissingDocumentUseCase {
  const UploadMissingDocumentUseCase(this._repository);
  final MissingDocumentRepository _repository;

  Future<Either<Failure, void>> call({
    required String requestId,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  }) =>
      _repository.upload(requestId: requestId, document: document, onProgress: onProgress);
}

class PickDocumentUseCase {
  const PickDocumentUseCase(this._picker);
  final DocumentPicker _picker;

  Future<Either<Failure, PickedDocument?>> call(DocumentSource source, {required List<String> allowedExtensions}) =>
      _picker.pick(source, allowedExtensions: allowedExtensions);
}
