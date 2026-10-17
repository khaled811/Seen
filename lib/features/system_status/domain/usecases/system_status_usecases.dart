import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/app_status.dart';
import '../repositories/access_request_repository.dart';
import '../repositories/app_status_repository.dart';

class GetAppStatusUseCase {
  const GetAppStatusUseCase(this._repository);

  final AppStatusRepository _repository;

  Future<Either<Failure, AppStatus>> call() => _repository.fetch();
}

class RequestAccessUseCase {
  const RequestAccessUseCase(this._repository);

  final AccessRequestRepository _repository;

  Future<Either<Failure, void>> call(String area) => _repository.request(area);
}
