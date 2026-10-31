import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/repositories/document_file_repository.dart';
import '../datasources/document_file_remote_data_source.dart';

class DocumentFileRepositoryImpl implements DocumentFileRepository {
  const DocumentFileRepositoryImpl({required DocumentFileRemoteDataSource remote}) : _remote = remote;

  final DocumentFileRemoteDataSource _remote;

  @override
  Future<Either<Failure, Uint8List>> fetch(String url) => _remote.fetch(url);

  @override
  Future<Either<Failure, Uint8List>> fetchFile(String fileId) async {
    // A link lives about 90 seconds: one that is already dead gets one new link.
    for (var attempt = 0; attempt < 2; attempt++) {
      final link = await _remote.signedUrl(fileId);
      if (link case Left(:final value)) return Left(value);
      final bytes = await _remote.fetch((link as Right<Failure, String>).value);
      if (bytes case Left(value: ServerFailure(code: 'document_link_expired'))) continue;
      return bytes;
    }
    return const Left(ServerFailure('The link expired.', code: 'document_link_expired'));
  }
}
