import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../dynamic_forms/domain/validators/dynamic_field_validator.dart';
import '../../../wallet/domain/usecases/get_wallet_balance_usecase.dart';
import '../../domain/entities/service_booking_request.dart';
import '../../domain/entities/traveler_info.dart';
import '../../domain/usecases/booking_draft_usecases.dart';
import '../../domain/usecases/get_available_services_usecase.dart';
import '../../domain/usecases/submit_booking_usecase.dart';
import 'service_booking_event.dart';
import 'service_booking_state.dart';

class ServiceBookingBloc extends Bloc<ServiceBookingEvent, ServiceBookingState> {
  ServiceBookingBloc({
    required GetAvailableServicesUseCase getAvailableServicesUseCase,
    required SubmitBookingUseCase submitBookingUseCase,
    required GetWalletBalanceUseCase getWalletBalanceUseCase,
    required DynamicFieldValidator validator,
    DeleteBookingDraftUseCase? deleteDraftUseCase,
  })  : _deleteDraft = deleteDraftUseCase,
        _getAvailableServicesUseCase = getAvailableServicesUseCase,
        _submitBookingUseCase = submitBookingUseCase,
        _getWalletBalanceUseCase = getWalletBalanceUseCase,
        _validator = validator,
        super(const ServiceBookingInitial()) {
    on<ServiceCatalogRequested>(_onCatalogRequested, transformer: droppable());
    on<ServiceSelected>(_onServiceSelected);
    on<BookingDraftResumed>(_onDraftResumed);
    on<BookingDraftSaved>(_onDraftSaved);
    on<TravelerFieldChanged>(_onTravelerFieldChanged);
    on<TravelerAdded>(_onTravelerAdded);
    on<TravelerRemoved>(_onTravelerRemoved);
    on<ActiveTravelerChanged>(_onActiveTravelerChanged);
    on<TravelerContinuePressed>(_onTravelerContinuePressed);
    on<ReviewReadyAcknowledged>(_onReviewReadyAcknowledged);
    on<BookingSubmitted>(_onBookingSubmitted, transformer: droppable());
    on<BookingReset>(_onBookingReset);
  }

  final GetAvailableServicesUseCase _getAvailableServicesUseCase;
  final SubmitBookingUseCase _submitBookingUseCase;
  final GetWalletBalanceUseCase _getWalletBalanceUseCase;
  final DynamicFieldValidator _validator;
  final DeleteBookingDraftUseCase? _deleteDraft;

  int _nextTravelerSeq = 0;
  String _newTravelerId() => 'traveler-${_nextTravelerSeq++}';

  Future<void> _onCatalogRequested(
    ServiceCatalogRequested event,
    Emitter<ServiceBookingState> emit,
  ) async {
    emit(const ServiceCatalogLoading());
    final result = await _getAvailableServicesUseCase();
    emit(
      result.match(
        (failure) => ServiceCatalogFailure(failure.message),
        (services) => ServiceCatalogLoaded(services),
      ),
    );
  }

  Future<void> _onServiceSelected(
    ServiceSelected event,
    Emitter<ServiceBookingState> emit,
  ) async {
    emit(
      ServiceBookingInProgress(
        service: event.service,
        travelerFields: event.travelerFields,
        travelers: [TravelerInfo(id: _newTravelerId(), fieldValues: const {})],
        activeTravelerIndex: 0,
        walletBalanceLoading: true,
      ),
    );

    final balanceResult = await _getWalletBalanceUseCase();
    final current = state;
    if (current is! ServiceBookingInProgress) return; // Reset/navigated away meanwhile.
    emit(
      balanceResult.match(
        (failure) => current.copyWith(walletBalanceLoading: false),
        (balance) => current.copyWith(walletBalance: balance, walletBalanceLoading: false),
      ),
    );
  }

  Future<void> _onDraftResumed(BookingDraftResumed event, Emitter<ServiceBookingState> emit) async {
    final travelers = [
      for (final t in event.draft.travelers) TravelerInfo(id: _newTravelerId(), fieldValues: Map.of(t.fieldValues)),
    ];
    emit(
      ServiceBookingInProgress(
        service: event.service,
        travelerFields: event.travelerFields,
        travelers: travelers.isEmpty ? [TravelerInfo(id: _newTravelerId(), fieldValues: const {})] : travelers,
        activeTravelerIndex: 0,
        walletBalanceLoading: true,
        draftId: event.draft.id,
      ),
    );
    final balanceResult = await _getWalletBalanceUseCase();
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    emit(
      balanceResult.match(
        (failure) => current.copyWith(walletBalanceLoading: false),
        (balance) => current.copyWith(walletBalance: balance, walletBalanceLoading: false),
      ),
    );
  }

  void _onDraftSaved(BookingDraftSaved event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    emit(current.copyWith(draftId: event.draftId));
  }

  void _onTravelerFieldChanged(
    TravelerFieldChanged event,
    Emitter<ServiceBookingState> emit,
  ) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    if (event.travelerIndex < 0 || event.travelerIndex >= current.travelers.length) return;

    final travelers = [...current.travelers];
    final traveler = travelers[event.travelerIndex];
    final updatedValues = Map<String, Object?>.from(traveler.fieldValues)
      ..[event.fieldKey] = event.value;
    travelers[event.travelerIndex] = traveler.copyWith(fieldValues: updatedValues);

    // Clear this field's error as soon as it's edited, mirroring
    // `WizardFormCubit` — re-validated on the next Continue/Submit.
    final travelerErrors = Map<String, Map<String, String>>.from(current.travelerErrors);
    final fieldErrors = travelerErrors[traveler.id];
    if (fieldErrors != null && fieldErrors.containsKey(event.fieldKey)) {
      final updatedFieldErrors = Map<String, String>.from(fieldErrors)..remove(event.fieldKey);
      travelerErrors[traveler.id] = updatedFieldErrors;
    }

    emit(current.copyWith(travelers: travelers, travelerErrors: travelerErrors));
  }

  void _onTravelerAdded(TravelerAdded event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    final travelers = [
      ...current.travelers,
      TravelerInfo(id: _newTravelerId(), fieldValues: const {}),
    ];
    emit(current.copyWith(travelers: travelers, activeTravelerIndex: travelers.length - 1));
  }

  void _onTravelerRemoved(TravelerRemoved event, Emitter<ServiceBookingState> emit) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    if (current.travelers.length <= 1) return; // Always keep at least one traveler.
    if (event.travelerIndex < 0 || event.travelerIndex >= current.travelers.length) return;

    final removedId = current.travelers[event.travelerIndex].id;
    final travelers = [...current.travelers]..removeAt(event.travelerIndex);
    final travelerErrors = Map<String, Map<String, String>>.from(current.travelerErrors)
      ..remove(removedId);
    final activeTravelerIndex = current.activeTravelerIndex.clamp(0, travelers.length - 1);

    emit(
      current.copyWith(
        travelers: travelers,
        travelerErrors: travelerErrors,
        activeTravelerIndex: activeTravelerIndex,
      ),
    );
  }

  void _onActiveTravelerChanged(
    ActiveTravelerChanged event,
    Emitter<ServiceBookingState> emit,
  ) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    if (event.travelerIndex < 0 || event.travelerIndex >= current.travelers.length) return;
    emit(current.copyWith(activeTravelerIndex: event.travelerIndex));
  }

  void _onTravelerContinuePressed(
    TravelerContinuePressed event,
    Emitter<ServiceBookingState> emit,
  ) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    final errors = _validateTravelers(current);
    if (errors.isEmpty) {
      emit(current.copyWith(travelerErrors: errors, reviewReady: true));
      return;
    }
    final firstInvalidIndex = current.travelers.indexWhere((t) => errors.containsKey(t.id));
    emit(
      current.copyWith(
        travelerErrors: errors,
        activeTravelerIndex: firstInvalidIndex >= 0 ? firstInvalidIndex : current.activeTravelerIndex,
      ),
    );
  }

  void _onReviewReadyAcknowledged(
    ReviewReadyAcknowledged event,
    Emitter<ServiceBookingState> emit,
  ) {
    final current = state;
    if (current is! ServiceBookingInProgress) return;
    emit(current.copyWith(reviewReady: false));
  }

  Future<void> _onBookingSubmitted(
    BookingSubmitted event,
    Emitter<ServiceBookingState> emit,
  ) async {
    final current = state;
    if (current is! ServiceBookingInProgress) return;

    // Defense in depth: re-validate even though the review screen is only
    // reachable after a clean pass, in case traveler data changed since.
    final errors = _validateTravelers(current);
    if (errors.isNotEmpty) {
      emit(current.copyWith(travelerErrors: errors, reviewReady: false));
      return;
    }

    emit(
      current.copyWith(
        submissionStatus: BookingSubmissionStatus.submitting,
        clearSubmissionError: true,
      ),
    );

    final request = ServiceBookingRequest(
      serviceId: current.service.id,
      travelers: current.travelers,
    );
    final result = await _submitBookingUseCase(request);
    // Sent: the draft it came from is no longer needed.
    if (result.isRight() && current.draftId != null) await _deleteDraft?.call(current.draftId!);
    final latest = state;
    if (latest is! ServiceBookingInProgress) return;
    emit(
      result.match(
        (failure) => latest.copyWith(
          submissionStatus: BookingSubmissionStatus.failure,
          submissionError: failure.message,
        ),
        (bookingResult) => latest.copyWith(
          submissionStatus: BookingSubmissionStatus.success,
          submissionResult: bookingResult,
        ),
      ),
    );
  }

  void _onBookingReset(BookingReset event, Emitter<ServiceBookingState> emit) {
    emit(const ServiceBookingInitial());
  }

  Map<String, Map<String, String>> _validateTravelers(ServiceBookingInProgress state) {
    final errors = <String, Map<String, String>>{};
    for (final traveler in state.travelers) {
      final fieldErrors = <String, String>{};
      for (final field in state.travelerFields) {
        final error = _validator.validate(field, traveler.fieldValues[field.key]);
        if (error != null) fieldErrors[field.key] = error;
      }
      if (fieldErrors.isNotEmpty) errors[traveler.id] = fieldErrors;
    }
    return errors;
  }
}
