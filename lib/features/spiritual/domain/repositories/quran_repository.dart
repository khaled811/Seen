import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/quran_data.dart';

abstract interface class QuranRepository {
  /// The whole bundled Quran. Parsed once; later calls return the cached copy.
  Future<Either<Failure, QuranData>> load();
}
