import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/tawaf_session.dart';
import '../repositories/tawaf_session_repository.dart';

class UndoLapUseCase {
  const UndoLapUseCase(this._repository);

  final TawafSessionRepository _repository;

  Future<Either<Failure, TawafSession>> call(TawafSession session) async {
    if (!session.canUndo) return Right(session);
    final next = session.undoLap();
    return (await _repository.save(next)).map((_) => next);
  }
}
