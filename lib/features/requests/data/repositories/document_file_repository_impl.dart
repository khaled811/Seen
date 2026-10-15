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
}
