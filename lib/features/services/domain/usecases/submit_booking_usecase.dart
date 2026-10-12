import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/service_booking_request.dart';
import '../entities/service_booking_result.dart';
import '../repositories/services_repository.dart';

class SubmitBookingUseCase {
  const SubmitBookingUseCase(this._repository);

  final ServicesRepository _repository;

  Future<Either<Failure, ServiceBookingResult>> call(
    ServiceBookingRequest request,
  ) =>
      _repository.submitBooking(request);
}
