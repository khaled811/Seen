import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/missing_document.dart';

/// Opens the system file / gallery / camera picker. Right(null) = the user
/// cancelled; Left = the source could not be opened (e.g. camera permission
/// denied).
abstract interface class DocumentPicker {
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions});
}
