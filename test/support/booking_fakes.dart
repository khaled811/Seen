import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/features/services/domain/entities/prefill.dart';
import 'package:seen_booking/features/services/domain/repositories/prefill_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/prefill_usecases.dart';
import 'package:seen_booking/features/services/presentation/bloc/prefill_cubit.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/dynamic_form_field.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/field_condition.dart';
import 'package:seen_booking/features/requests/domain/entities/cancel_reason.dart';
import 'package:seen_booking/features/requests/domain/entities/request_detail.dart';
import 'package:seen_booking/features/requests/domain/entities/requests_page.dart';
import 'package:seen_booking/features/requests/domain/repositories/requests_repository.dart';
import 'package:seen_booking/features/services/domain/entities/booking_document.dart';
import 'package:seen_booking/features/services/domain/entities/draft_review.dart';
import 'package:seen_booking/features/services/domain/entities/field_value_input.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_result.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/booking_flow_repository.dart';

/// A service the way the server describes it: three fields (one hidden until the
/// traveler is married) and one required document.
const bookingTestService = ServiceDefinition(
  id: 'svc-1',
  category: ServiceCategory.egyptNationalSecurity,
  name: 'Egypt approval',
  description: '',
  perPersonPriceCents: 8500,
  availability: ServiceAvailability.available,
  fields: [
    DynamicFormField(key: 'fullName', definitionId: 'f-name', type: FieldType.text, label: 'Full name', required: true),
    DynamicFormField(key: 'birthDate', definitionId: 'f-birth', type: FieldType.date, label: 'Birth date', required: true),
    DynamicFormField(key: 'status', definitionId: 'f-status', type: FieldType.text, label: 'Status'),
    DynamicFormField(
      key: 'spouse',
      definitionId: 'f-spouse',
      type: FieldType.text,
      label: 'Spouse',
      required: true,
      showIf: FieldCondition(field: 'status', op: 'eq', values: ['married']),
    ),
  ],
  documents: [ServiceDocumentRequirement(id: 'd1', key: 'passport', label: 'Passport', required: true)],
);

DraftReview bookingTestReview({
  String requestId = 'req-1',
  bool canSubmit = true,
  int travelers = 1,
  bool holdDeferred = false,
  bool? fundsSufficient = true,
  int? availableAfterCents = 11500,
  List<String> errors = const [],
  String travelerName = 'A*** S***',
  String serviceName = 'Egypt approval',
}) =>
    DraftReview(
      requestId: requestId,
      status: 'draft',
      serviceId: 'svc-1',
      serviceName: serviceName,
      travelers: [
        for (var i = 0; i < travelers; i++)
          ReviewTraveler(
            id: 't${i + 1}',
            index: i,
            name: travelerName,
            nameMasked: true,
            passportNumber: 'X***89',
            documentsCount: 1,
          ),
      ],
      quote: ReviewQuote(
        currency: 'USD',
        unitPriceCents: 8500,
        travelerCount: travelers,
        totalCents: 8500 * travelers,
        balanceCents: 20000,
        availableAfterCents: availableAfterCents,
        fundsSufficient: fundsSufficient,
        holdDeferred: holdDeferred,
        slaHours: 48,
      ),
      canSubmit: canSubmit,
      errors: errors,
    );

/// A scripted server for the booking flow: every call is recorded and answers
/// with whatever the test put in the matching `...Result`.
class FakeBookingFlowRepository implements BookingFlowRepository {
  Either<Failure, String>? createResult;
  Either<Failure, List<String>>? addResult;
  Either<Failure, void> uploadResult = const Right(null);
  Either<Failure, DraftReview>? reviewResult;
  Either<Failure, ServiceBookingResult> submitResult =
      const Right(ServiceBookingResult(requestId: 'req-1', status: RequestStatus.submitted, referenceCode: 'SB-20481'));

  /// When set, the call waits for it (to test calls that overlap).
  Completer<void>? holdSubmit;
  Completer<void>? holdCreate;

  final created = <String>[];
  final added = <(String, List<List<FieldValueInput>>)>[];
  final uploads = <BookingDocumentUpload>[];
  final reviewed = <String>[];
  final submitted = <String>[];

  int _seq = 0;

  @override
  Future<Either<Failure, String>> createDraft(String serviceTypeId) async {
    created.add(serviceTypeId);
    await holdCreate?.future;
    return createResult ?? Right('req-${++_seq}');
  }

  @override
  Future<Either<Failure, List<String>>> addTravelers(String requestId, List<List<FieldValueInput>> travelers) async {
    added.add((requestId, travelers));
    return addResult ?? Right([for (var i = 0; i < travelers.length; i++) 't${i + 1}']);
  }

  @override
  Future<Either<Failure, void>> uploadDocument(BookingDocumentUpload upload) async {
    uploads.add(upload);
    return uploadResult;
  }

  @override
  Future<Either<Failure, DraftReview>> reviewDraft(String requestId) async {
    reviewed.add(requestId);
    return reviewResult ?? Right(bookingTestReview(requestId: requestId));
  }

  @override
  Future<Either<Failure, ServiceBookingResult>> submit(String requestId) async {
    submitted.add(requestId);
    await holdSubmit?.future;
    return submitResult;
  }
}

RequestDetail fakeRequestDetail(String id, RequestStatus status, {String referenceId = 'SB-20481'}) => RequestDetail(
      id: id,
      referenceId: referenceId,
      serviceName: 'Egypt approval',
      status: status,
      totalPriceCents: 8500,
      submittedAt: DateTime(2026, 10, 19),
      travelers: const [],
      timeline: const [],
    );

/// Requests repository for the parts the booking flow uses: read one request, cancel one.
class FakeBookingRequestsRepository implements RequestsRepository {
  Either<Failure, RequestDetail> detailResult = Right(fakeRequestDetail('req-1', RequestStatus.draft, referenceId: ''));
  Either<Failure, RequestDetail?> cancelResult = const Right(null);
  RequestsPage page = const RequestsPage(items: [], total: 0, hasMore: false);
  Either<Failure, RequestsPage>? pageResult;

  final cancelled = <String>[];
  final details = <String>[];
  final pages = <({String group, int offset, int limit})>[];

  @override
  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId) async {
    details.add(requestId);
    return detailResult;
  }

  @override
  Future<Either<Failure, RequestDetail?>> cancelRequest(String requestId, {CancelReason? reason}) async {
    cancelled.add(requestId);
    return cancelResult;
  }

  @override
  Future<Either<Failure, RequestsPage>> getRequests({
    String group = 'all',
    String? search,
    int offset = 0,
    int limit = 30,
  }) async {
    pages.add((group: group, offset: offset, limit: limit));
    return pageResult ?? Right(page);
  }

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async => const Right(null);
}

/// No earlier requests to copy: the traveler form shows no "copy" link.
PrefillCubit noPrefillCubit(String serviceId) => PrefillCubit(
      candidates: GetPrefillCandidatesUseCase(FakeNoPrefill()),
      values: GetPrefillValuesUseCase(FakeNoPrefill()),
      serviceId: serviceId,
    );

class FakeNoPrefill implements PrefillRepository {
  @override
  Future<Either<Failure, List<PrefillCandidate>>> candidates(String serviceId) async => const Right([]);

  @override
  Future<Either<Failure, PrefillValues>> valuesFrom({required String serviceId, required String sourceRequestId}) async =>
      const Right(PrefillValues([]));
}
