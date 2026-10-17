import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/requests_repository.dart';

class RemindApproverUseCase {
  const RemindApproverUseCase(this._repository);

  final RequestsRepository _repository;

  Future<Either<Failure, void>> call(String requestId) => _repository.remindApprover(requestId);
}
