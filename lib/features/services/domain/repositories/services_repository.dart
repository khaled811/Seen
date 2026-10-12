import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/service_booking_request.dart';
import '../entities/service_booking_result.dart';
import '../entities/service_definition.dart';

abstract interface class ServicesRepository {
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices();

  Future<Either<Failure, ServiceBookingResult>> submitBooking(
    ServiceBookingRequest request,
  );
}
