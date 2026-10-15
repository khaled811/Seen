import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

abstract interface class DocumentFileRepository {
  /// Downloads the document at [url].
  Future<Either<Failure, Uint8List>> fetch(String url);
}
