import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/service_definition.dart';
import '../repositories/services_repository.dart';

class GetAvailableServicesUseCase {
  const GetAvailableServicesUseCase(this._repository);

  final ServicesRepository _repository;

  Future<Either<Failure, List<ServiceDefinition>>> call() =>
      _repository.getAvailableServices();
}
