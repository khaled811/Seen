import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/tawaf_session_repository.dart';

/// Ends the rite: forgets the persisted session.
class EndSessionUseCase {
  const EndSessionUseCase(this._repository);

  final TawafSessionRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.clear();
}
