import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/booking_document.dart';
import '../entities/draft_review.dart';
import '../entities/field_value_input.dart';
import '../entities/service_booking_result.dart';
import '../repositories/booking_flow_repository.dart';

class CreateDraftRequestUseCase {
  const CreateDraftRequestUseCase(this._repository);
  final BookingFlowRepository _repository;

  Future<Either<Failure, String>> call(String serviceTypeId) => _repository.createDraft(serviceTypeId);
}

class AddTravelersUseCase {
  const AddTravelersUseCase(this._repository);
  final BookingFlowRepository _repository;

  Future<Either<Failure, List<String>>> call(String requestId, List<List<FieldValueInput>> travelers) =>
      _repository.addTravelers(requestId, travelers);
}

class UploadBookingDocumentUseCase {
  const UploadBookingDocumentUseCase(this._repository);
  final BookingFlowRepository _repository;

  Future<Either<Failure, void>> call(BookingDocumentUpload upload) => _repository.uploadDocument(upload);
}

class ReviewDraftUseCase {
  const ReviewDraftUseCase(this._repository);
  final BookingFlowRepository _repository;

  Future<Either<Failure, DraftReview>> call(String requestId) => _repository.reviewDraft(requestId);
}

class SubmitDraftRequestUseCase {
  const SubmitDraftRequestUseCase(this._repository);
  final BookingFlowRepository _repository;

  Future<Either<Failure, ServiceBookingResult>> call(String requestId) => _repository.submit(requestId);
}
