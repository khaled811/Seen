import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/booking_document.dart';
import '../entities/draft_review.dart';
import '../entities/field_value_input.dart';
import '../entities/service_booking_result.dart';

/// The server side of filing a request (contract 10.2): draft, travelers,
/// documents, review, submit. Nothing here is persisted on the device.
abstract interface class BookingFlowRepository {
  /// `createDraftRequest`: the new draft's request id.
  Future<Either<Failure, String>> createDraft(String serviceTypeId);

  /// `batchAddTravelers`: the server ids of the travelers, in the order sent.
  /// A rejected value comes back as a `ValidationFailure` with per-traveler issues.
  Future<Either<Failure, List<String>>> addTravelers(String requestId, List<List<FieldValueInput>> travelers);

  /// `POST /files/upload/` with `kind=document`.
  Future<Either<Failure, void>> uploadDocument(BookingDocumentUpload upload);

  /// `portalDraftReview`.
  Future<Either<Failure, DraftReview>> reviewDraft(String requestId);

  /// `submitRequest`. Not idempotent: after an ambiguous failure read the
  /// request before sending it again.
  Future<Either<Failure, ServiceBookingResult>> submit(String requestId);
}
