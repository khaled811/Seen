import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/tawaf_session.dart';
import '../repositories/tawaf_session_repository.dart';

class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._repository);

  final TawafSessionRepository _repository;

  Future<Either<Failure, TawafSession?>> call() => _repository.load();
}
