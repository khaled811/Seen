import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/service_definition.dart';

abstract interface class ServicesRepository {
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices();
}
