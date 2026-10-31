// The booking flow against a scripted server: validation, filing the draft
// (create, travelers, documents), the quote, submit, and every way a call can fail.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/dynamic_forms/domain/validators/dynamic_field_validator.dart';
import 'package:seen_booking/features/dynamic_forms/domain/validators/form_validation_messages.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/services/domain/entities/field_value_input.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_result.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/booking_flow_usecases.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_state.dart';

import '../../../../support/booking_fakes.dart';

const _messages = FormValidationMessages(
  required: 'required',
  invalidEmail: 'invalidEmail',
  invalidPhone: 'invalidPhone',
  invalidNumber: 'invalidNumber',
  invalidDate: 'invalidDate',
  invalidSelection: 'invalidSelection',
  tooShort: _id,
  tooLong: _id,
  numberTooSmall: _id,
  numberTooLarge: _id,
  expiryTooSoon: _id,
  dateInFuture: _idString,
);
String _id(num n) => '$n';
String _idString(String s) => s;

class _FakeServicesRepository implements ServicesRepository {
  Either<Failure, List<ServiceDefinition>> catalogResult = const Right([bookingTestService]);

  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async => catalogResult;
}

const _passport = PickedDocument(path: '/tmp/passport.jpg', fileName: 'passport.jpg', sizeBytes: 1000);

void main() {
  late _FakeServicesRepository catalog;
  late FakeBookingFlowRepository flow;
  late FakeBookingRequestsRepository requests;
  late ServiceBookingBloc bloc;

  setUp(() {
    catalog = _FakeServicesRepository();
    flow = FakeBookingFlowRepository();
    requests = FakeBookingRequestsRepository();
    bloc = ServiceBookingBloc(
      getAvailableServicesUseCase: GetAvailableServicesUseCase(catalog),
      createDraftUseCase: CreateDraftRequestUseCase(flow),
      addTravelersUseCase: AddTravelersUseCase(flow),
      uploadDocumentUseCase: UploadBookingDocumentUseCase(flow),
      reviewDraftUseCase: ReviewDraftUseCase(flow),
      submitDraftUseCase: SubmitDraftRequestUseCase(flow),
      getRequestDetailUseCase: GetRequestDetailUseCase(requests),
      validator: const DynamicFieldValidator(_messages),
      referenceRetryDelay: Duration.zero,
    );
  });

  tearDown(() => bloc.close());

  ServiceBookingInProgress inProgress() => bloc.state as ServiceBookingInProgress;

  Future<void> send(ServiceBookingEvent event) async {
    bloc.add(event);
    await pumpEventQueue();
  }

  void fill({int traveler = 0, String name = 'Amal Saleh', Object? birth, String? status, String? spouse}) {
    bloc
      ..add(TravelerFieldChanged(travelerIndex: traveler, fieldKey: 'fullName', value: name))
      ..add(TravelerFieldChanged(travelerIndex: traveler, fieldKey: 'birthDate', value: birth ?? DateTime(1990, 3, 5)));
    if (status != null) bloc.add(TravelerFieldChanged(travelerIndex: traveler, fieldKey: 'status', value: status));
    if (spouse != null) bloc.add(TravelerFieldChanged(travelerIndex: traveler, fieldKey: 'spouse', value: spouse));
  }

  Future<void> startAndFill() async {
    await send(const ServiceSelected(service: bookingTestService));
    fill();
    await pumpEventQueue();
  }

  group('catalog', () {
    test('loads the services', () async {
      await send(const ServiceCatalogRequested());
      expect(bloc.state, isA<ServiceCatalogLoaded>());
    });

    test('a failure keeps the failure for localized text', () async {
      catalog.catalogResult = const Left(NetworkFailure('off'));
      await send(const ServiceCatalogRequested());
      expect((bloc.state as ServiceCatalogFailure).failure, isA<NetworkFailure>());
    });
  });

  group('filing the draft', () {
    test('invalid travelers stop at the form: nothing reaches the server', () async {
      await send(const ServiceSelected(service: bookingTestService));
      await send(const TravelerContinuePressed());
      final errors = inProgress().travelerErrors.values.single;
      expect(errors['fullName'], 'required');
      expect(errors['birthDate'], 'required');
      expect(errors.containsKey('spouse'), isFalse); // hidden: never an error
      expect(flow.created, isEmpty);
    });

    test('a field shown by a condition is required once it shows', () async {
      await send(const ServiceSelected(service: bookingTestService));
      fill(status: 'married');
      await pumpEventQueue();
      await send(const TravelerContinuePressed());
      expect(inProgress().travelerErrors.values.single.keys, ['spouse']);
      expect(flow.created, isEmpty);
    });

    test('valid travelers: draft, travelers, then the quote; dates as YYYY-MM-DD, hidden fields not sent', () async {
      await startAndFill();
      // A value typed while the field was visible is not sent once it is hidden.
      bloc.add(const TravelerFieldChanged(travelerIndex: 0, fieldKey: 'spouse', value: 'stale'));
      await pumpEventQueue();
      await send(const TravelerContinuePressed());

      expect(flow.created, ['svc-1']);
      expect(flow.added, hasLength(1));
      expect(flow.added.single.$1, 'req-1');
      expect(flow.added.single.$2.single, const [
        FieldValueInput(fieldDefinitionId: 'f-name', value: 'Amal Saleh'),
        FieldValueInput(fieldDefinitionId: 'f-birth', value: '1990-03-05'),
      ]);
      expect(flow.reviewed, ['req-1']);
      final state = inProgress();
      expect(state.reviewReady, isTrue);
      expect(state.syncStatus, BookingSyncStatus.idle);
      expect(state.review!.quote.totalCents, 8500);
    });

    test('documents go to the server traveler for the requirement, each once', () async {
      await startAndFill();
      final documents = {bookingDocumentSlot(inProgress().travelers.single.id, 'd1'): _passport};
      await send(TravelerContinuePressed(documents: documents));
      expect(flow.uploads, hasLength(1));
      expect(flow.uploads.single.requestId, 'req-1');
      expect(flow.uploads.single.travelerId, 't1');
      expect(flow.uploads.single.requirementId, 'd1');
      expect(flow.uploads.single.document, _passport);
    });

    test('an upload that fails keeps the draft; the retry sends only what is missing', () async {
      await startAndFill();
      final documents = {bookingDocumentSlot(inProgress().travelers.single.id, 'd1'): _passport};
      flow.uploadResult = const Left(ServerFailure('x', statusCode: 413, code: 'file_too_large'));
      await send(TravelerContinuePressed(documents: documents));
      expect(inProgress().syncStatus, BookingSyncStatus.failure);
      expect((inProgress().syncFailure as ServerFailure).code, 'file_too_large');
      expect(inProgress().reviewReady, isFalse);

      flow.uploadResult = const Right(null);
      await send(TravelerContinuePressed(documents: documents));
      expect(flow.created, hasLength(1)); // same draft
      expect(flow.added, hasLength(1)); // travelers not added twice
      expect(flow.uploads, hasLength(2)); // the failed one is retried, once
      expect(inProgress().reviewReady, isTrue);
    });

    test('a second tap while filing is dropped', () async {
      await startAndFill();
      final gate = flow.holdCreate = Completer<void>();
      bloc
        ..add(const TravelerContinuePressed())
        ..add(const TravelerContinuePressed());
      await pumpEventQueue();
      expect(inProgress().isSaving, isTrue);
      gate.complete();
      await pumpEventQueue();
      expect(flow.created, hasLength(1));
    });

    test('Continue again with nothing changed reuses the draft', () async {
      await startAndFill();
      await send(const TravelerContinuePressed());
      await send(const ReviewReadyAcknowledged());
      await send(const TravelerContinuePressed());
      expect(flow.created, hasLength(1));
      expect(flow.added, hasLength(1));
      expect(flow.reviewed, hasLength(2));
    });

    test('changed travelers: a new draft is filed (the old one cannot be cancelled and stays)', () async {
      await startAndFill();
      await send(const TravelerContinuePressed());
      await send(const ReviewReadyAcknowledged());
      await send(const TravelerFieldChanged(travelerIndex: 0, fieldKey: 'fullName', value: 'Amal S.'));
      await send(const TravelerContinuePressed());
      expect(requests.cancelled, isEmpty); // a draft cannot be cancelled, so none is tried
      expect(flow.created, hasLength(2));
      expect(flow.added.last.$1, 'req-2');
      expect(inProgress().review!.requestId, 'req-2');
    });

    test('values the server refuses are marked on their fields, with no generic failure', () async {
      await startAndFill();
      flow.addResult = const Left(
        ValidationFailure('x', issues: [ValidationIssue(code: 'format_invalid', travelerIndex: 0, field: 'fullName')]),
      );
      await send(const TravelerContinuePressed());
      final state = inProgress();
      expect(state.travelerErrors.values.single['fullName'], '${bookingServerIssuePrefix}format_invalid');
      expect(state.syncStatus, BookingSyncStatus.idle);
      expect(state.syncFailure, isNull);
      // The draft is kept (empty) for the next try: it is not created again.
      flow.addResult = null;
      await send(const TravelerFieldChanged(travelerIndex: 0, fieldKey: 'fullName', value: 'Amal Saleh'));
      await send(const TravelerContinuePressed());
      expect(flow.created, hasLength(1));
      expect(state.travelers, hasLength(1));
      expect(inProgress().reviewReady, isTrue);
    });

    test('a timeout while adding travelers starts a new draft next time (no duplicate travelers)', () async {
      await startAndFill();
      flow.addResult = const Left(NetworkFailure('timeout', isTimeout: true));
      await send(const TravelerContinuePressed());
      expect(inProgress().syncFailure, isA<NetworkFailure>());
      expect(requests.cancelled, isEmpty);

      flow.addResult = null;
      await send(const TravelerContinuePressed());
      expect(flow.created, hasLength(2));
      expect(inProgress().reviewReady, isTrue);
    });

    test('a server error (5xx) while adding travelers is treated the same way', () async {
      await startAndFill();
      flow.addResult = const Left(ServerFailure('boom', statusCode: 502));
      await send(const TravelerContinuePressed());
      expect(requests.cancelled, isEmpty);
    });

    test('no connection when creating the draft: failure, nothing else attempted, retry works', () async {
      await startAndFill();
      flow.createResult = const Left(NetworkFailure('off'));
      await send(const TravelerContinuePressed());
      expect(inProgress().syncFailure, isA<NetworkFailure>());
      expect(flow.added, isEmpty);

      flow.createResult = null;
      await send(const TravelerContinuePressed());
      expect(inProgress().reviewReady, isTrue);
    });

    test('an expired session is reported as such (the app routes to sign-in)', () async {
      await startAndFill();
      flow.createResult = const Left(UnauthorizedFailure('over', 'session_expired'));
      await send(const TravelerContinuePressed());
      expect(inProgress().syncFailure, isA<UnauthorizedFailure>());
      expect(inProgress().syncStatus, BookingSyncStatus.failure);
    });

    test('permission denied is reported, not retried', () async {
      await startAndFill();
      flow.createResult = const Left(ForbiddenFailure('no', 'permission_denied'));
      await send(const TravelerContinuePressed());
      expect(inProgress().syncFailure, isA<ForbiddenFailure>());
      expect(flow.created, hasLength(1));
    });

    test('a quote that cannot load is a failure of the step', () async {
      await startAndFill();
      flow.reviewResult = const Left(NetworkFailure('off'));
      await send(const TravelerContinuePressed());
      expect(inProgress().syncStatus, BookingSyncStatus.failure);
      expect(inProgress().reviewReady, isFalse);
      // The draft is on the server; the retry only asks for the quote again.
      flow.reviewResult = null;
      await send(const TravelerContinuePressed());
      expect(flow.created, hasLength(1));
      expect(inProgress().reviewReady, isTrue);
    });

    test('save only: the server holds the draft, no quote is loaded, the form is told to close', () async {
      await startAndFill();
      await send(const TravelerContinuePressed(saveOnly: true));
      expect(flow.added, hasLength(1));
      expect(flow.reviewed, isEmpty);
      expect(inProgress().draftSaved, isTrue);
      expect(inProgress().reviewReady, isFalse);
      await send(const DraftSavedAcknowledged());
      expect(inProgress().draftSaved, isFalse);
    });

    test('several travelers go in one batch, in order; the limit holds', () async {
      await send(const ServiceSelected(service: bookingTestService));
      for (var i = 0; i < maxTravelersPerRequest + 2; i++) {
        bloc.add(const TravelerAdded());
      }
      await pumpEventQueue();
      expect(inProgress().travelers, hasLength(maxTravelersPerRequest));
      bloc.add(const TravelerRemoved(0));
      await pumpEventQueue();
      expect(inProgress().travelers, hasLength(maxTravelersPerRequest - 1));
      for (var i = 0; i < inProgress().travelers.length; i++) {
        fill(traveler: i, name: 'Traveler $i');
      }
      await pumpEventQueue();
      await send(const TravelerContinuePressed());
      expect(flow.added.single.$2, hasLength(maxTravelersPerRequest - 1));
      expect(flow.added.single.$2[3][0].value, 'Traveler 3');
    });

    test('abandoning a session cancels nothing (the API cannot cancel a draft)', () async {
      await startAndFill();
      flow.addResult = const Left(ServerFailure('nope', code: 'something_else'));
      await send(const TravelerContinuePressed());
      await send(const BookingReset());
      expect(requests.cancelled, isEmpty);
    });
  });

  group('submit', () {
    Future<void> reachReview({bool canSubmit = true, bool holdDeferred = false}) async {
      flow.reviewResult = Right(bookingTestReview(canSubmit: canSubmit, holdDeferred: holdDeferred));
      await startAndFill();
      await send(const TravelerContinuePressed());
    }

    test('submits the draft and keeps the confirmation', () async {
      await reachReview();
      await send(const BookingSubmitted());
      expect(flow.submitted, ['req-1']);
      final state = inProgress();
      expect(state.submissionStatus, BookingSubmissionStatus.success);
      expect(state.submissionResult!.referenceCode, 'SB-20481');
    });

    test('the server says it cannot be submitted: nothing is sent', () async {
      await reachReview(canSubmit: false);
      await send(const BookingSubmitted());
      expect(flow.submitted, isEmpty);
    });

    test('a double tap submits once', () async {
      await reachReview();
      final gate = flow.holdSubmit = Completer<void>();
      bloc
        ..add(const BookingSubmitted())
        ..add(const BookingSubmitted());
      await pumpEventQueue();
      expect(inProgress().submissionStatus, BookingSubmissionStatus.submitting);
      gate.complete();
      await pumpEventQueue();
      expect(flow.submitted, hasLength(1));
    });

    test('a reference that lags is read again before the confirmation is shown', () async {
      await reachReview();
      flow.submitResult = const Right(ServiceBookingResult(requestId: 'req-1', status: RequestStatus.submitted));
      requests.detailResult = Right(fakeRequestDetail('req-1', RequestStatus.submitted));
      await send(const BookingSubmitted());
      expect(requests.details, ['req-1']);
      expect(inProgress().submissionResult!.referenceCode, 'SB-20481');
    });

    test('a reference that never shows still confirms the submit (the id is not used instead)', () async {
      await reachReview();
      flow.submitResult = const Right(ServiceBookingResult(requestId: 'req-1', status: RequestStatus.submitted));
      requests.detailResult = Right(fakeRequestDetail('req-1', RequestStatus.submitted, referenceId: ''));
      await send(const BookingSubmitted());
      expect(inProgress().submissionStatus, BookingSubmissionStatus.success);
      expect(inProgress().submissionResult!.hasReference, isFalse);
      expect(requests.details, hasLength(2));
    });

    test('a timeout is reconciled by reading the request: it went through', () async {
      await reachReview();
      flow.submitResult = const Left(NetworkFailure('timeout', isTimeout: true));
      requests.detailResult = Right(fakeRequestDetail('req-1', RequestStatus.pendingManagementApproval));
      await send(const BookingSubmitted());
      expect(flow.submitted, hasLength(1)); // never sent again
      expect(inProgress().submissionStatus, BookingSubmissionStatus.success);
      expect(inProgress().submissionResult!.status, RequestStatus.pendingManagementApproval);
    });

    test('a timeout where the request is still a draft is a failure; the retry is the person\'s', () async {
      await reachReview();
      flow.submitResult = const Left(NetworkFailure('timeout', isTimeout: true));
      requests.detailResult = Right(fakeRequestDetail('req-1', RequestStatus.draft));
      await send(const BookingSubmitted());
      expect(inProgress().submissionStatus, BookingSubmissionStatus.failure);
      expect(inProgress().submissionFailure, isA<NetworkFailure>());
      expect(flow.submitted, hasLength(1));
    });

    test('insufficient funds is reported with its code', () async {
      await reachReview();
      flow.submitResult = const Left(ServerFailure('x', code: 'insufficient_funds'));
      await send(const BookingSubmitted());
      expect((inProgress().submissionFailure as ServerFailure).code, 'insufficient_funds');
      // A definite refusal is not "ambiguous": the request was not read.
      expect(requests.details, isEmpty);
    });

    test('an expired session while submitting is reported as such', () async {
      await reachReview();
      flow.submitResult = const Left(UnauthorizedFailure('over', 'not_authenticated'));
      await send(const BookingSubmitted());
      expect(inProgress().submissionFailure, isA<UnauthorizedFailure>());
    });

    test('the quote can be refreshed (after a top-up)', () async {
      await reachReview();
      flow.reviewResult = Right(bookingTestReview(fundsSufficient: false, availableAfterCents: -500));
      await send(const BookingReviewRefreshRequested());
      expect(flow.reviewed, hasLength(2));
      expect(inProgress().review!.quote.fundsSufficient, isFalse);
      expect(inProgress().reviewLoading, isFalse);
    });

    test('a quote refresh that fails keeps the last quote and says why', () async {
      await reachReview();
      flow.reviewResult = const Left(NetworkFailure('off'));
      await send(const BookingReviewRefreshRequested());
      expect(inProgress().review, isNotNull);
      expect(inProgress().reviewFailure, isA<NetworkFailure>());
    });
  });

  group('a draft opened from the list', () {
    test('goes straight to the review and cannot be edited', () async {
      flow.reviewResult = Right(bookingTestReview(requestId: 'req-9', travelers: 2));
      await send(const BookingDraftOpened('req-9'));
      final state = inProgress();
      expect(state.resumed, isTrue);
      expect(state.review!.requestId, 'req-9');
      expect(state.service.id, 'svc-1');
      await send(const TravelerAdded());
      await send(const TravelerContinuePressed());
      expect(flow.created, isEmpty);
      expect(flow.added, isEmpty);
    });

    test('it can be submitted from there', () async {
      flow.reviewResult = Right(bookingTestReview(requestId: 'req-9'));
      await send(const BookingDraftOpened('req-9'));
      flow.submitResult = const Right(ServiceBookingResult(requestId: 'req-9', status: RequestStatus.submitted, referenceCode: 'SB-9'));
      await send(const BookingSubmitted());
      expect(flow.submitted, ['req-9']);
      expect(inProgress().submissionResult!.referenceCode, 'SB-9');
    });

    test('a quote that cannot load keeps the failure for a retry', () async {
      flow.reviewResult = const Left(NetworkFailure('off'));
      await send(const BookingDraftOpened('req-9'));
      expect(inProgress().review, isNull);
      expect(inProgress().reviewFailure, isA<NetworkFailure>());
      expect(inProgress().reviewLoading, isFalse);

      // The retry opens the same draft again.
      flow.reviewResult = Right(bookingTestReview(requestId: 'req-9'));
      await send(const BookingReviewRefreshRequested());
      expect(flow.reviewed, ['req-9', 'req-9']);
      expect(inProgress().review!.requestId, 'req-9');
      expect(inProgress().reviewFailure, isNull);
    });
  });
  group('copying an earlier request (prefill)', () {
    test('fills the matching fields of the first traveler, ignores keys the service does not ask for, sends nothing', () async {
      await send(const ServiceSelected(service: bookingTestService));
      await send(const TravelerPrefillApplied([
        {'fullName': 'Walid', 'birthDate': '1990-01-02', 'notAField': 'x'},
      ]));
      expect(inProgress().travelers.single.fieldValues, {'fullName': 'Walid', 'birthDate': '1990-01-02'});
      expect(flow.reviewed, isEmpty);
    });

    test('adds travelers as needed (up to the limit) and keeps what was typed in other fields', () async {
      await send(const ServiceSelected(service: bookingTestService));
      await send(const TravelerFieldChanged(travelerIndex: 0, fieldKey: 'status', value: 'single'));
      await send(TravelerPrefillApplied([
        for (var i = 0; i < 60; i++) {'fullName': 'T$i'},
      ]));
      final travelers = inProgress().travelers;
      expect(travelers.length, maxTravelersPerRequest);
      expect(travelers.first.fieldValues, {'status': 'single', 'fullName': 'T0'});
      expect(travelers.last.fieldValues['fullName'], 'T${maxTravelersPerRequest - 1}');
    });

    test('a resumed draft is not touched', () async {
      await send(const BookingDraftOpened('req-1'));
      await send(const TravelerPrefillApplied([
        {'fullName': 'X'},
      ]));
      expect(inProgress().travelers, isEmpty);
    });
  });

  test('a server field issue keeps its values through the text of the form and back', () {
    final text = encodeServerIssue('out_of_range', {'min': 1, 'max': 9});
    expect(text, startsWith(bookingServerIssuePrefix));
    final back = decodeServerIssue(text);
    expect(back.code, 'out_of_range');
    expect(back.params, {'min': 1, 'max': 9});
    expect(decodeServerIssue(encodeServerIssue('required', const {})), (code: 'required', params: const <String, Object?>{}));
    expect(decodeServerIssue('${bookingServerIssuePrefix}x|{not json').code, 'x'); // a broken tail never throws
  });
}
