import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

abstract interface class DocumentFileRepository {
  /// Downloads the document at [url].
  Future<Either<Failure, Uint8List>> fetch(String url);

  /// Downloads a stored file by id: a fresh signed link is requested for every
  /// call (and once more if the link had already expired), fetched at once and
  /// never kept.
  Future<Either<Failure, Uint8List>> fetchFile(String fileId);
}
