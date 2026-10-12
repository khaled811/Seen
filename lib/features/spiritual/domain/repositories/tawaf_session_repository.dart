import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/tawaf_session.dart';

abstract interface class TawafSessionRepository {
  /// The persisted active session, or `null` when none exists.
  Future<Either<Failure, TawafSession?>> load();
  Future<Either<Failure, Unit>> save(TawafSession session);
  Future<Either<Failure, Unit>> clear();
}
