import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/tasbeeh.dart';

abstract interface class TasbeehRepository {
  /// The saved progress, or null on first use.
  Future<Either<Failure, TasbeehProgress?>> load();

  /// Persists [progress]. Implementations may coalesce rapid saves, but the
  /// latest one must always reach storage.
  Future<Either<Failure, Unit>> save(TasbeehProgress progress);
}

abstract interface class DhikrCatalog {
  Future<Either<Failure, List<TasbeehDhikr>>> adhkar();
}
