import 'package:equatable/equatable.dart';

import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../domain/entities/booking_draft.dart';
import '../../domain/entities/service_definition.dart';

sealed class ServiceBookingEvent extends Equatable {
  const ServiceBookingEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on the service-selection screen's entry.
final class ServiceCatalogRequested extends ServiceBookingEvent {
  const ServiceCatalogRequested();
}

/// Starts a new booking session for [service]. [travelerFields] is
/// resolved by the caller (needs `AppLocalizations` for labels — see
/// `ServiceTravelerFields`), so the Bloc itself never needs l10n.
final class ServiceSelected extends ServiceBookingEvent {
  const ServiceSelected({required this.service, required this.travelerFields});

  final ServiceDefinition service;
  final List<DynamicFormField> travelerFields;

  @override
  List<Object?> get props => [service, travelerFields];
}

/// Opens the traveler form with the data of a saved draft (Figma REQ-01).
final class BookingDraftResumed extends ServiceBookingEvent {
  const BookingDraftResumed({required this.service, required this.travelerFields, required this.draft});

  final ServiceDefinition service;
  final List<DynamicFormField> travelerFields;
  final BookingDraft draft;

  @override
  List<Object?> get props => [service, travelerFields, draft];
}

/// The draft was saved (or its id is now known): later saves overwrite it.
final class BookingDraftSaved extends ServiceBookingEvent {
  const BookingDraftSaved(this.draftId);

  final String draftId;

  @override
  List<Object?> get props => [draftId];
}

final class TravelerFieldChanged extends ServiceBookingEvent {
  const TravelerFieldChanged({
    required this.travelerIndex,
    required this.fieldKey,
    required this.value,
  });

  final int travelerIndex;
  final String fieldKey;
  final Object? value;

  @override
  List<Object?> get props => [travelerIndex, fieldKey, value];
}

final class TravelerAdded extends ServiceBookingEvent {
  const TravelerAdded();
}

final class TravelerRemoved extends ServiceBookingEvent {
  const TravelerRemoved(this.travelerIndex);

  final int travelerIndex;

  @override
  List<Object?> get props => [travelerIndex];
}

final class ActiveTravelerChanged extends ServiceBookingEvent {
  const ActiveTravelerChanged(this.travelerIndex);

  final int travelerIndex;

  @override
  List<Object?> get props => [travelerIndex];
}

/// Validates every traveler's fields and, if all are clean, flips
/// `reviewReady` so the UI can navigate to the review screen.
final class TravelerContinuePressed extends ServiceBookingEvent {
  const TravelerContinuePressed();
}

/// Dispatched by the UI immediately after acting on `reviewReady`, so
/// returning to this screen later doesn't re-trigger navigation.
final class ReviewReadyAcknowledged extends ServiceBookingEvent {
  const ReviewReadyAcknowledged();
}

final class BookingSubmitted extends ServiceBookingEvent {
  const BookingSubmitted();
}

/// Returns to the initial (pre-selection) state — e.g. after a completed
/// booking, or the user backing out entirely.
final class BookingReset extends ServiceBookingEvent {
  const BookingReset();
}
