import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

/// Hands a document to the user: save a copy on the device or open the system
/// share sheet. Right(false) = the user cancelled.
abstract interface class DocumentExporter {
  Future<Either<Failure, bool>> save(String fileName, Uint8List bytes);

  Future<Either<Failure, bool>> share(String fileName, Uint8List bytes);
}
