import 'package:fpdart/fpdart.dart';

import '../error/failure.dart';

/// Sends a file ahead of the call that uses it (`POST /files/upload/` with
/// `kind=ticket_attachment`): the answer is the file id that the second call
/// (`submitTopUp(receiptFileId)`, `openGeneralTicket(attachmentFileId)`,
/// `setMyAvatar(fileId)`) refers to. A staged file nobody attaches is deleted by
/// the server after a day. Pure Dart.
abstract interface class StagedFileUploader {
  Future<Either<Failure, String>> stage({
    required String path,
    required String fileName,
    void Function(double fraction)? onProgress,
  });
}
