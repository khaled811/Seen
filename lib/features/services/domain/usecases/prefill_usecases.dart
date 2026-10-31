import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/prefill.dart';
import '../repositories/prefill_repository.dart';

class GetPrefillCandidatesUseCase {
  const GetPrefillCandidatesUseCase(this._repository);

  final PrefillRepository _repository;

  Future<Either<Failure, List<PrefillCandidate>>> call(String serviceId) => _repository.candidates(serviceId);
}

class GetPrefillValuesUseCase {
  const GetPrefillValuesUseCase(this._repository);

  final PrefillRepository _repository;

  Future<Either<Failure, PrefillValues>> call({required String serviceId, required String sourceRequestId}) =>
      _repository.valuesFrom(serviceId: serviceId, sourceRequestId: sourceRequestId);
}
