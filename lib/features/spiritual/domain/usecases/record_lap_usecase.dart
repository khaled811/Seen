import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/tawaf_session.dart';
import '../repositories/tawaf_session_repository.dart';

/// Records the next lap and persists it. Taps within [debounce] of the
/// previous recorded lap are rejected (accidental double-tap in a crowd).
class RecordLapUseCase {
  const RecordLapUseCase(this._repository);

  static const debounce = Duration(milliseconds: 1500);

  final TawafSessionRepository _repository;

  Future<Either<Failure, TawafSession>> call(
    TawafSession session, {
    required DateTime now,
  }) async {
    if (session.done) return Right(session);
    if (session.lapTimestamps.isNotEmpty &&
        now.difference(session.lapTimestamps.last) < debounce) {
      return const Left(ValidationFailure('lap_debounced'));
    }
    final next = session.recordLap(now);
    return (await _repository.save(next)).map((_) => next);
  }
}
