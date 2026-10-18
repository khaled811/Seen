import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/missing_document.dart';

/// Failure codes for a camera / photo-library permission that was refused for good.
const cameraDeniedCode = 'CAMERA_PERMISSION_DENIED';
const photosDeniedCode = 'PHOTOS_PERMISSION_DENIED';

/// Opens the system file / gallery / camera picker. Right(null) = the user
/// cancelled; Left = the source could not be opened (e.g. camera permission
/// denied).
abstract interface class DocumentPicker {
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions});
}
