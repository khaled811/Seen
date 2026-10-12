import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/service_booking_request.dart';
import '../../domain/entities/service_booking_result.dart';
import '../../domain/entities/service_definition.dart';
import '../../domain/repositories/services_repository.dart';
import '../datasources/services_remote_data_source.dart';
import '../models/service_booking_result_dto.dart';
import '../models/service_definition_dto.dart';

class ServicesRepositoryImpl implements ServicesRepository {
  ServicesRepositoryImpl({required ServicesRemoteDataSource remote}) : _remote = remote;

  final ServicesRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async {
    final result = await _remote.getAvailableServices();
    if (result case Left(:final value)) return Left(value);
    final dtos = (result as Right<Failure, List<ServiceDefinitionDto>>).value;
    return Right(dtos.map((dto) => dto.toEntity()).toList());
  }

  @override
  Future<Either<Failure, ServiceBookingResult>> submitBooking(
    ServiceBookingRequest request,
  ) async {
    final result = await _remote.submitBooking(request);
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, ServiceBookingResultDto>).value;
    return Right(dto.toEntity());
  }
}
