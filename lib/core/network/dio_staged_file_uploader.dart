import 'package:fpdart/fpdart.dart';

import '../error/failure.dart';
import '../services/staged_file_uploader.dart';
import 'file_upload_client.dart';

/// [StagedFileUploader] over the REST upload endpoint.
class DioStagedFileUploader implements StagedFileUploader {
  const DioStagedFileUploader(this._client);

  final FileUploadClient _client;

  @override
  Future<Either<Failure, String>> stage({
    required String path,
    required String fileName,
    void Function(double fraction)? onProgress,
  }) async {
    final result = await _client.upload(kind: 'ticket_attachment', path: path, fileName: fileName, onProgress: onProgress);
    return result.map((file) => file.fileId);
  }
}
