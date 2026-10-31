import 'package:equatable/equatable.dart';

import '../../../requests/domain/entities/missing_document.dart';
import '../../domain/entities/hospital.dart';
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

/// Starts a new booking session for [service]; the traveler form is the
/// service's own server-defined `fields`.
final class ServiceSelected extends ServiceBookingEvent {
  const ServiceSelected({required this.service, this.hospital});

  final ServiceDefinition service;

  /// Chosen first for a medical service (Figma BOOK-10).
  final HospitalChoice? hospital;

  @override
  List<Object?> get props => [service, hospital];
}

/// Opens a server draft (the drafts list) straight at its review. The
/// travelers of a draft come back masked and cannot be edited, so the review is
/// the only step left.
final class BookingDraftOpened extends ServiceBookingEvent {
  const BookingDraftOpened(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
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

/// The person chose to copy the details of an earlier request: its values fill the
/// matching fields (travelers are added as needed, up to the limit). Nothing is
/// sent; the person reviews the form and continues as usual.
final class TravelerPrefillApplied extends ServiceBookingEvent {
  const TravelerPrefillApplied(this.travelers);

  /// Per traveler: field key -> value.
  final List<Map<String, String>> travelers;

  @override
  List<Object?> get props => [travelers];
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

/// The key of one document slot: a traveler (local id) and a document
/// requirement of the service.
String bookingDocumentSlot(String travelerId, String requirementId) => '$travelerId|$requirementId';

/// Validates every traveler and, if all are clean, files them on the server
/// (draft, travelers, documents) and loads the review: `reviewReady` then flips
/// so the UI can open the review screen. With [saveOnly] it stops after the
/// server holds the draft and flips `draftSaved` instead (leaving the form).
///
/// [documents] are the files picked so far, keyed by [bookingDocumentSlot].
final class TravelerContinuePressed extends ServiceBookingEvent {
  const TravelerContinuePressed({this.documents = const {}, this.saveOnly = false});

  final Map<String, PickedDocument> documents;
  final bool saveOnly;

  @override
  List<Object?> get props => [documents, saveOnly];
}

/// Dispatched by the UI immediately after acting on `reviewReady`, so
/// returning to this screen later doesn't re-trigger navigation.
final class ReviewReadyAcknowledged extends ServiceBookingEvent {
  const ReviewReadyAcknowledged();
}

final class DraftSavedAcknowledged extends ServiceBookingEvent {
  const DraftSavedAcknowledged();
}

final class BookingSubmitted extends ServiceBookingEvent {
  const BookingSubmitted();
}

/// Returns to the initial (pre-selection) state — e.g. after a completed
/// booking, or the user backing out entirely.
final class BookingReset extends ServiceBookingEvent {
  const BookingReset();
}

/// Reloads the server's quote (after a top-up from the review screen, Figma BOOK-08).
final class BookingReviewRefreshRequested extends ServiceBookingEvent {
  const BookingReviewRefreshRequested();
}
