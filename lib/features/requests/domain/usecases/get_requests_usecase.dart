import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/request_summary.dart';
import '../repositories/requests_repository.dart';

class GetRequestsUseCase {
  const GetRequestsUseCase(this._repository);

  final RequestsRepository _repository;

  Future<Either<Failure, List<RequestSummary>>> call() => _repository.getRequests();
}
