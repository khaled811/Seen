import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/dua.dart';

abstract interface class DuaRepository {
  /// Duas visible to the user; implementations must drop unreviewed entries
  /// in release builds.
  Future<Either<Failure, List<Dua>>> getDuas({DuaCategory? category});
}
