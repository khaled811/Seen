import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/missing_document.dart';

abstract interface class MissingDocumentRepository {
  Future<Either<Failure, MissingDocumentRequest>> getMissingDocument(String requestId);

  /// Sends [document] to [target]. [onProgress] gets 0..1 while it is sent.
  Future<Either<Failure, void>> upload({
    required UploadTarget target,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  });
}
