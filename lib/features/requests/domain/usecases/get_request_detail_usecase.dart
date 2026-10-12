import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/request_detail.dart';
import '../repositories/requests_repository.dart';

class GetRequestDetailUseCase {
  const GetRequestDetailUseCase(this._repository);

  final RequestsRepository _repository;

  Future<Either<Failure, RequestDetail>> call(String requestId) =>
      _repository.getRequestDetail(requestId);
}
