import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/passport_reading.dart';

/// Reads a passport's data page from a photo (`POST /files/read-passport/`).
abstract interface class PassportReaderRepository {
  /// The photo at [path] is sent once and then DELETED from the device, whatever the result: the
  /// app keeps no copy of a passport image. An empty reading is a success with no suggestions.
  Future<Either<Failure, PassportReading>> read({required String path, required String fileName});
}
