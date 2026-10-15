import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/missing_document.dart';

abstract interface class MissingDocumentRepository {
  Future<Either<Failure, MissingDocumentRequest>> getMissingDocument(String requestId);

  /// Sends [document] for [requestId]. [onProgress] gets 0..1 when the transport
  /// can report it.
  Future<Either<Failure, void>> upload({
    required String requestId,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  });
}
