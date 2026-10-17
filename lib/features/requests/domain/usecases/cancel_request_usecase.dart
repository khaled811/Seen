import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/cancel_reason.dart';
import '../entities/request_detail.dart';
import '../repositories/requests_repository.dart';

class CancelRequestUseCase {
  const CancelRequestUseCase(this._repository);

  final RequestsRepository _repository;

  Future<Either<Failure, RequestDetail>> call(String requestId, {CancelReason? reason}) =>
      _repository.cancelRequest(requestId, reason: reason);
}
