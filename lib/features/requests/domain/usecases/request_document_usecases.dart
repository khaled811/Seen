import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/document_file_repository.dart';
import '../services/document_exporter.dart';

class FetchDocumentFileUseCase {
  const FetchDocumentFileUseCase(this._repository);
  final DocumentFileRepository _repository;

  Future<Either<Failure, Uint8List>> call(String url) => _repository.fetch(url);
}

class SaveDocumentUseCase {
  const SaveDocumentUseCase(this._exporter);
  final DocumentExporter _exporter;

  Future<Either<Failure, bool>> call(String fileName, Uint8List bytes) => _exporter.save(fileName, bytes);
}

class ShareDocumentUseCase {
  const ShareDocumentUseCase(this._exporter);
  final DocumentExporter _exporter;

  Future<Either<Failure, bool>> call(String fileName, Uint8List bytes) => _exporter.share(fileName, bytes);
}
