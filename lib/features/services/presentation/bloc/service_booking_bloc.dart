import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../../dynamic_forms/domain/validators/dynamic_field_validator.dart';
import '../../../requests/domain/entities/missing_document.dart';
import '../../../requests/domain/usecases/get_request_detail_usecase.dart';
import '../../domain/entities/booking_document.dart';
import '../../domain/entities/field_value_input.dart';
import '../../domain/entities/service_booking_result.dart';
import '../../domain/entities/service_definition.dart';
import '../../domain/entities/traveler_info.dart';
import '../../domain/usecases/booking_flow_usecases.dart';
import '../../domain/usecases/get_available_services_usecase.dart';
import 'service_booking_event.dart';
import 'service_booking_state.dart';

/// What the server holds for the booking in progress: the draft, whether its
/// travelers were added, exactly what was sent, and which files already went.
class _ServerDraft {
  _ServerDraft(this.requestId);

  final String requestId;

  /// Server ids of the travelers, in the order of [payload]; null until added.
  List<String>? travelerIds;
  List<List<FieldValueInput>>? payload;
  final uploaded = <String>{};
}

class ServiceBookingBloc extends Bloc<ServiceBookingEvent, ServiceBookingState> {
  ServiceBookingBloc({
    required GetAvailableServicesUseCase getAvailableServicesUseCase,
    required CreateDraftRequestUseCase createDraftUseCase,
    required AddTravelersUseCase addTravelersUseCase,
    required UploadBookingDocumentUseCase uploadDocumentUseCase,
    required ReviewDraftUseCase reviewDraftUseCase,
    required SubmitDraftRequestUseCase submitDraftUseCase,
    required GetRequestDetailUseCase getRequestDetailUseCase,
    required DynamicFieldValidator validator,
    this.referenceRetryDelay = const Duration(seconds: 1),
  })  : _getAvailableServicesUseCase = getAvailableServicesUseCase,
        _createDraft = createDraftUseCase,
        _addTravelers = addTravelersUseCase,
        _uploadDocument = uploadDocumentUseCase,
        _reviewDraft = reviewDraftUseCase,
        _submitDraft = submitDraftUseCase,
        _getRequestDetail = getRequestDetailUseCase,
        _validator = validator,
        super(const ServiceBookingInitial()) {
    on<ServiceCatalogRequested>(_onCatalogRequested, transformer: droppable());
    on<ServiceSelected>(_onServiceSelected);
    on<BookingDraftOpened>(_onDraftOpened, transformer: restartable());
    on<TravelerFieldChanged>(_onTravelerFieldChanged);
    on<TravelerPrefillApplied>(_onPrefillApplied);
    on<TravelerAdded>(_onTravelerAdded);
    on<TravelerRemoved>(_onTravelerRemoved);
    on<ActiveTravelerChanged>(_onActiveTravelerChanged);
    // One filing at a time: a second tap while the first runs is dropped.
    on<TravelerContinuePressed>(_onContinuePressed, transformer: droppable());
    on<ReviewReadyAcknowledged>(_onReviewReadyAcknowledged);
    on<DraftSavedAcknowledged>(_onDraftSavedAcknowledged);
    on<BookingSubmitted>(_onBookingSubmitted, transformer: droppable());
    on<BookingReset>(_onBookingReset);
    on<BookingReviewRefreshRequested>(_onReviewRefresh, transformer: restartable());
  }

  final GetAvailableServicesUseCase _getAvailableServicesUseCase;
  final CreateDraftRequestUseCase _createDraft;
  final AddTravelersUseCase _addTravelers;
  final UploadBookingDocumentUseCase _uploadDocument;
  final ReviewDraftUseCase _reviewDraft;
  final SubmitDraftRequestUseCase _submitDraft;
  final GetRequestDetailUseCase _getRequestDetail;
  final DynamicFieldValidator _validator;

  /// How long to wait before re-reading a request whose `referenceCode` has not
  /// appeared yet (contract 10.2 step 7).
  final Duration referenceRetryDelay;

  _ServerDraft? _server;

  /// The draft opened from the list, so a failed load can be retried.
  String? _openedDraftId;
  int _nextTravelerSeq = 0;
  String _newTravelerId() => 'traveler-${_nextTravelerSeq++}';

  Future<void> _onCatalogRequested(ServiceCatalogRequested event, Emitter<ServiceBookingState> emit) async {
    emit(const ServiceCatalogLoading());
    final result = await _getAvailableServicesUseCase();
    emit(
      result.match(
        (failure) => ServiceCatalogFailure(failure.message, failure: failure),
        (services) => ServiceCatalogLoaded(services),
      ),
    );
  }

  void _onServiceSelected(ServiceSelected event, Emitter<ServiceBookingState> emit) {
    _server = null;
    emit(
      ServiceBookingInProgress(
        service: event.service,
        travelers: [TravelerInfo(id: _newTravelerId(), fieldValues: const {})],
        activeTravelerIndex: 0,
        hospital: event.hospital,
      ),
    );
  }

  Future<void> _onDraftOpened(BookingDraftOpened event, Emitter<ServiceBookingState> emit) async {
    _server = null;
    _openedDraftId = event.requestId;
    emit(
      const ServiceBookingInProgress(
        service: ServiceDefinition(
          id: '',
          category: ServiceCategory.unknown,
          name: '',
          description: '',
          perPersonPriceCents: 0,
          availability: ServiceAvailability.available,
        ),
        travelers: [],
        activeTravelerIndex: 0,
        reviewLoading: true,
        resumed: true,
      ),
    );
    final result = await _reviewDraft(event.requestId);
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    emit(
      result.match(
        (failure) => current.copyWith(reviewLoading: false, reviewFailure: failure),
        (review) => ServiceBookingInProgress(
          service: ServiceDefinition(
            id: review.serviceId,
            category: ServiceCategory.unknown,
            name: review.serviceName,
            description: '',
            perPersonPriceCents: review.quote.unitPriceCents ?? 0,
            availability: ServiceAvailability.available,
          ),
          travelers: const [],
          activeTravelerIndex: 0,
          review: review,
          resumed: true,
        ),
      ),
    );
  }

  void _onTravelerFieldChanged(TravelerFieldChanged event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    if (event.travelerIndex < 0 || event.travelerIndex >= current.travelers.length) return;

    final travelers = [...current.travelers];
    final traveler = travelers[event.travelerIndex];
    final updatedValues = Map<String, Object?>.from(traveler.fieldValues)..[event.fieldKey] = event.value;
    travelers[event.travelerIndex] = traveler.copyWith(fieldValues: updatedValues);

    // Clear this field's error as soon as it's edited — re-validated on the next Continue.
    final travelerErrors = Map<String, Map<String, String>>.from(current.travelerErrors);
    final fieldErrors = travelerErrors[traveler.id];
    if (fieldErrors != null && fieldErrors.containsKey(event.fieldKey)) {
      travelerErrors[traveler.id] = Map<String, String>.from(fieldErrors)..remove(event.fieldKey);
    }

    emit(current.copyWith(travelers: travelers, travelerErrors: travelerErrors));
  }

  void _onPrefillApplied(TravelerPrefillApplied event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress || current.resumed) return;
    // Only the service's own fields are taken; a key it does not ask for is ignored.
    final keys = {for (final f in current.service.fields) f.key};
    final travelers = [...current.travelers];
    final errors = Map<String, Map<String, String>>.from(current.travelerErrors);
    for (var i = 0; i < event.travelers.length && i < maxTravelersPerRequest; i++) {
      final values = {for (final e in event.travelers[i].entries) if (keys.contains(e.key)) e.key: e.value};
      if (values.isEmpty) continue;
      if (i >= travelers.length) travelers.add(TravelerInfo(id: _newTravelerId(), fieldValues: const {}));
      final traveler = travelers[i];
      travelers[i] = traveler.copyWith(fieldValues: {...traveler.fieldValues, ...values});
      errors.remove(traveler.id); // checked again on Continue
    }
    emit(current.copyWith(travelers: travelers, travelerErrors: errors));
  }

  void _onTravelerAdded(TravelerAdded event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress || current.resumed) return;
    if (current.travelers.length >= maxTravelersPerRequest) return;
    final travelers = [...current.travelers, TravelerInfo(id: _newTravelerId(), fieldValues: const {})];
    emit(current.copyWith(travelers: travelers, activeTravelerIndex: travelers.length - 1));
  }

  void _onTravelerRemoved(TravelerRemoved event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    if (current.travelers.length <= 1) return; // Always keep at least one traveler.
    if (event.travelerIndex < 0 || event.travelerIndex >= current.travelers.length) return;

    final removedId = current.travelers[event.travelerIndex].id;
    final travelers = [...current.travelers]..removeAt(event.travelerIndex);
    final travelerErrors = Map<String, Map<String, String>>.from(current.travelerErrors)..remove(removedId);
    emit(
      current.copyWith(
        travelers: travelers,
        travelerErrors: travelerErrors,
        activeTravelerIndex: current.activeTravelerIndex.clamp(0, travelers.length - 1),
      ),
    );
  }

  void _onActiveTravelerChanged(ActiveTravelerChanged event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    if (event.travelerIndex < 0 || event.travelerIndex >= current.travelers.length) return;
    emit(current.copyWith(activeTravelerIndex: event.travelerIndex));
  }

  void _onReviewReadyAcknowledged(ReviewReadyAcknowledged event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    emit(current.copyWith(reviewReady: false));
  }

  void _onDraftSavedAcknowledged(DraftSavedAcknowledged event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    emit(current.copyWith(draftSaved: false));
  }

  // --- Continue: validate, file on the server, quote ---------------------------------

  Future<void> _onContinuePressed(TravelerContinuePressed event, Emitter<ServiceBookingState> emit) async {
    final current = state;
    if (current is! ServiceBookingInProgress || current.resumed) return;

    final errors = _validateTravelers(current);
    if (errors.isNotEmpty) {
      final firstInvalid = current.travelers.indexWhere((t) => errors.containsKey(t.id));
      emit(
        current.copyWith(
          travelerErrors: errors,
          activeTravelerIndex: firstInvalid >= 0 ? firstInvalid : current.activeTravelerIndex,
        ),
      );
      return;
    }

    emit(
      current.copyWith(
        travelerErrors: const {},
        syncStatus: BookingSyncStatus.saving,
        clearSyncFailure: true,
        reviewReady: false,
        draftSaved: false,
      ),
    );

    final payload = _payload(current);
    final failure = await _fileOnServer(current, payload, event.documents);
    final latest = state;
    if (latest is! ServiceBookingInProgress) return;

    if (failure != null) {
      emit(_withSyncFailure(latest, failure));
      return;
    }
    if (event.saveOnly) {
      emit(latest.copyWith(syncStatus: BookingSyncStatus.idle, draftSaved: true));
      return;
    }

    final reviewResult = await _reviewDraft(_server!.requestId);
    final afterReview = state;
    if (afterReview is! ServiceBookingInProgress) return;
    emit(
      reviewResult.match(
        (failure) => afterReview.copyWith(syncStatus: BookingSyncStatus.failure, syncFailure: failure),
        (review) => afterReview.copyWith(
          syncStatus: BookingSyncStatus.idle,
          review: review,
          clearReviewFailure: true,
          reviewReady: true,
        ),
      ),
    );
  }

  /// Makes the server's draft match [payload] and holds [documents]. Returns the
  /// failure that stopped it, or null. Safe to call again after a failure: what
  /// already went through is not sent twice.
  Future<Failure?> _fileOnServer(
    ServiceBookingInProgress current,
    List<List<FieldValueInput>> payload,
    Map<String, PickedDocument> documents,
  ) async {
    var server = _server;

    // The server has no way to edit or remove a traveler: changed data means a
    // new draft. The old one cannot be cancelled either (a draft only moves to
    // "submitted"), so it stays in the drafts list.
    if (server != null && server.travelerIds != null && !_samePayload(server.payload, payload)) {
      server = _server = null;
    }

    if (server == null) {
      final created = await _createDraft(current.service.id);
      if (created case Left(:final value)) return value;
      server = _server = _ServerDraft((created as Right<Failure, String>).value);
    }

    if (server.travelerIds == null) {
      final added = await _addTravelers(server.requestId, payload);
      if (added case Left(:final value)) {
        // After a timeout the server may or may not hold the travelers; sending
        // them again could duplicate them. Start a new draft next time (this one
        // cannot be cancelled and stays in the drafts list).
        if (_isAmbiguous(value)) _server = null;
        return value;
      }
      server
        ..travelerIds = (added as Right<Failure, List<String>>).value
        ..payload = payload;
    }

    final ids = server.travelerIds!;
    for (var i = 0; i < ids.length && i < current.travelers.length; i++) {
      for (final requirement in current.service.documents) {
        final slot = bookingDocumentSlot(current.travelers[i].id, requirement.id);
        final document = documents[slot];
        if (document == null) continue;
        final key = '${ids[i]}|${requirement.id}|${document.path}';
        if (server.uploaded.contains(key)) continue;
        final uploaded = await _uploadDocument(
          BookingDocumentUpload(
            requestId: server.requestId,
            travelerId: ids[i],
            requirementId: requirement.id,
            document: document,
          ),
        );
        if (uploaded case Left(:final value)) return value;
        server.uploaded.add(key);
      }
    }
    return null;
  }

  ServiceBookingInProgress _withSyncFailure(ServiceBookingInProgress current, Failure failure) {
    // Values the server refused are marked on their fields.
    if (failure is ValidationFailure && failure.issues.any((i) => i.field != null)) {
      final errors = <String, Map<String, String>>{};
      for (final issue in failure.issues) {
        final index = issue.travelerIndex ?? 0;
        final field = issue.field;
        if (field == null || index < 0 || index >= current.travelers.length) continue;
        (errors[current.travelers[index].id] ??= {})[field] = encodeServerIssue(issue.code, issue.params);
      }
      if (errors.isNotEmpty) {
        final first = current.travelers.indexWhere((t) => errors.containsKey(t.id));
        return current.copyWith(
          travelerErrors: errors,
          activeTravelerIndex: first >= 0 ? first : current.activeTravelerIndex,
          syncStatus: BookingSyncStatus.idle,
        );
      }
    }
    return current.copyWith(syncStatus: BookingSyncStatus.failure, syncFailure: failure);
  }

  // --- Review refresh and submit ---------------------------------------------------------

  Future<void> _onReviewRefresh(BookingReviewRefreshRequested event, Emitter<ServiceBookingState> emit) async {
    final before = state;
    if (before is! ServiceBookingInProgress) return;
    final requestId = before.review?.requestId;
    if (requestId == null) {
      // A draft opened from the list whose quote never loaded: open it again.
      final opened = _openedDraftId;
      if (before.resumed && opened != null) add(BookingDraftOpened(opened));
      return;
    }
    emit(before.copyWith(reviewLoading: true, clearReviewFailure: true));
    final result = await _reviewDraft(requestId);
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    emit(
      result.match(
        (failure) => current.copyWith(reviewLoading: false, reviewFailure: failure),
        (review) => current.copyWith(reviewLoading: false, review: review),
      ),
    );
  }

  Future<void> _onBookingSubmitted(BookingSubmitted event, Emitter<ServiceBookingState> emit) async {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    final review = current.review;
    // The server's own verdict gates the button; this guards a stray event.
    if (review == null || !review.canSubmit) return;

    emit(current.copyWith(submissionStatus: BookingSubmissionStatus.submitting, clearSubmissionFailure: true));

    final result = await _submitDraft(review.requestId);
    ServiceBookingResult? submitted;
    Failure? failure;
    switch (result) {
      case Right(:final value):
        submitted = value;
      case Left(:final value):
        failure = value;
        // A timeout does not say whether the request went through. Never send it
        // again blind: read it, and only a request that is no longer a draft counts.
        if (_isAmbiguous(value)) {
          final reread = await _getRequestDetail(review.requestId);
          if (reread case Right(value: final detail) when detail.status != RequestStatus.draft) {
            submitted = ServiceBookingResult(
              requestId: review.requestId,
              status: detail.status,
              referenceCode: detail.referenceId,
            );
            failure = null;
          }
        }
    }

    if (submitted != null && !submitted.hasReference) {
      submitted = await _awaitReference(submitted);
    }

    final latest = state;
    if (latest is! ServiceBookingInProgress) return;
    if (submitted != null) {
      _server = null;
      emit(latest.copyWith(submissionStatus: BookingSubmissionStatus.success, submissionResult: submitted));
    } else {
      emit(latest.copyWith(submissionStatus: BookingSubmissionStatus.failure, submissionFailure: failure));
    }
  }

  /// `referenceCode` can lag the submit by a moment: read the request again, a
  /// couple of times, before showing the confirmation without it.
  Future<ServiceBookingResult> _awaitReference(ServiceBookingResult result) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      await Future<void>.delayed(referenceRetryDelay);
      final reread = await _getRequestDetail(result.requestId);
      if (reread case Right(value: final detail) when detail.referenceId.isNotEmpty) {
        return result.withReference(detail.referenceId);
      }
    }
    return result;
  }

  void _onBookingReset(BookingReset event, Emitter<ServiceBookingState> emit) {
    _server = null;
    emit(const ServiceBookingInitial());
  }

  // --- helpers -----------------------------------------------------------------------------

  static bool _samePayload(List<List<FieldValueInput>>? a, List<List<FieldValueInput>> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (var j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) return false;
      }
    }
    return true;
  }

  static bool _isAmbiguous(Failure failure) =>
      failure is NetworkFailure || (failure is ServerFailure && failure.statusCode != null && failure.statusCode! >= 500);

  Map<String, Map<String, String>> _validateTravelers(ServiceBookingInProgress state) {
    final errors = <String, Map<String, String>>{};
    for (final traveler in state.travelers) {
      final fieldErrors = <String, String>{};
      for (final field in state.travelerFields) {
        final error = _validator.validate(field, traveler.fieldValues[field.key], values: traveler.fieldValues);
        if (error != null) fieldErrors[field.key] = error;
      }
      if (fieldErrors.isNotEmpty) errors[traveler.id] = fieldErrors;
    }
    return errors;
  }

  /// What goes to the server: per traveler, the visible fields that have a value,
  /// as `{fieldDefinitionId, value}` with dates as `YYYY-MM-DD`.
  List<List<FieldValueInput>> _payload(ServiceBookingInProgress state) => [
        for (final traveler in state.travelers)
          [
            for (final field in state.travelerFields)
              if (field.definitionId != null && field.isVisible(traveler.fieldValues))
                if (_text(traveler.fieldValues[field.key]) case final text? when text.isNotEmpty)
                  FieldValueInput(fieldDefinitionId: field.definitionId!, value: text),
          ],
      ];

  static String? _text(Object? value) {
    if (value == null) return null;
    if (value is DateTime) {
      return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }
    return value.toString().trim();
  }
}
