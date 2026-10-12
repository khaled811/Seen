import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/rite_mode.dart';
import '../entities/tawaf_session.dart';
import '../repositories/tawaf_session_repository.dart';

/// Begins a fresh session at lap 1 (replacing any stored one) and persists it.
class StartSessionUseCase {
  const StartSessionUseCase(this._repository);

  final TawafSessionRepository _repository;

  Future<Either<Failure, TawafSession>> call(
    RiteMode mode, {
    required DateTime now,
  }) async {
    final session = TawafSession.start(mode, now);
    return (await _repository.save(session)).map((_) => session);
  }
}
