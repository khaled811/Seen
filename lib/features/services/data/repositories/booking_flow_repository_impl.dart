import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/booking_document.dart';
import '../../domain/entities/draft_review.dart';
import '../../domain/entities/field_value_input.dart';
import '../../domain/entities/service_booking_result.dart';
import '../../domain/repositories/booking_flow_repository.dart';
import '../datasources/booking_flow_remote_data_source.dart';

class BookingFlowRepositoryImpl implements BookingFlowRepository {
  BookingFlowRepositoryImpl({required BookingFlowRemoteDataSource remote}) : _remote = remote;

  final BookingFlowRemoteDataSource _remote;

  @override
  Future<Either<Failure, String>> createDraft(String serviceTypeId) => _remote.createDraft(serviceTypeId);

  @override
  Future<Either<Failure, List<String>>> addTravelers(String requestId, List<List<FieldValueInput>> travelers) =>
      _remote.addTravelers(requestId, travelers);

  @override
  Future<Either<Failure, void>> uploadDocument(BookingDocumentUpload upload) => _remote.uploadDocument(upload);

  @override
  Future<Either<Failure, DraftReview>> reviewDraft(String requestId) => _remote.reviewDraft(requestId);

  @override
  Future<Either<Failure, ServiceBookingResult>> submit(String requestId) => _remote.submit(requestId);
}
