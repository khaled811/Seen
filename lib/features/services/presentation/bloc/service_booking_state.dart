import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../domain/entities/draft_review.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/entities/service_booking_result.dart';
import '../../domain/entities/service_definition.dart';
import '../../domain/entities/traveler_info.dart';

enum BookingSubmissionStatus { idle, submitting, success, failure }

/// Where the traveler data goes on Continue: the server holds it as a draft.
enum BookingSyncStatus { idle, saving, failure }

/// The most travelers one request takes (the server's `too_many_travelers` limit is 50:
/// requests/limits.py). The server stays the authority; the form only avoids a call it
/// knows will be refused.
const maxTravelersPerRequest = 50;

/// A field error that came from the server rather than from the app's own
/// validator: `server:<code>`. The form shows it in the user's language.
const bookingServerIssuePrefix = 'server:';

/// A field error from the server, as the form keeps it: `server:<code>` and, when the server
/// gave values for the text (a limit, a number of months), `|` and their JSON.
String encodeServerIssue(String code, Map<String, Object?> params) =>
    params.isEmpty ? '$bookingServerIssuePrefix$code' : '$bookingServerIssuePrefix$code|${jsonEncode(params)}';

/// The code and values inside [encodeServerIssue]'s text.
({String code, Map<String, Object?> params}) decodeServerIssue(String message) {
  final body = message.substring(bookingServerIssuePrefix.length);
  final bar = body.indexOf('|');
  if (bar < 0) return (code: body, params: const {});
  try {
    final decoded = jsonDecode(body.substring(bar + 1));
    return (code: body.substring(0, bar), params: decoded is Map<String, dynamic> ? decoded : const {});
  } catch (_) {
    return (code: body.substring(0, bar), params: const {});
  }
}

sealed class ServiceBookingState extends Equatable {
  const ServiceBookingState();

  @override
  List<Object?> get props => [];
}

final class ServiceBookingInitial extends ServiceBookingState {
  const ServiceBookingInitial();
}

final class ServiceCatalogLoading extends ServiceBookingState {
  const ServiceCatalogLoading();
}

final class ServiceCatalogFailure extends ServiceBookingState {
  const ServiceCatalogFailure(this.message, {this.failure});

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure];
}

final class ServiceCatalogLoaded extends ServiceBookingState {
  const ServiceCatalogLoaded(this.services);

  final List<ServiceDefinition> services;

  @override
  List<Object?> get props => [services];
}

/// The state of an in-progress booking session: from entering travelers,
/// through review, to submission. One cohesive flow, kept as a single state
/// (rather than one class per screen) because every field describes the same
/// ongoing session.
///
/// Traveler values live here in memory only; the server holds them once
/// Continue filed the draft. Nothing is written to the device.
final class ServiceBookingInProgress extends ServiceBookingState {
  const ServiceBookingInProgress({
    required this.service,
    required this.travelers,
    required this.activeTravelerIndex,
    this.travelerErrors = const {},
    this.reviewReady = false,
    this.draftSaved = false,
    this.syncStatus = BookingSyncStatus.idle,
    this.syncFailure,
    this.review,
    this.reviewLoading = false,
    this.reviewFailure,
    this.submissionStatus = BookingSubmissionStatus.idle,
    this.submissionFailure,
    this.submissionResult,
    this.hospital,
    this.resumed = false,
  });

  final ServiceDefinition service;

  /// The hospital chosen for a medical service; null for the others.
  final HospitalChoice? hospital;
  final List<TravelerInfo> travelers;
  final int activeTravelerIndex;

  /// Traveler id -> field key -> error message. Populated only after a
  /// validation pass (Continue), not on every keystroke. A message that starts
  /// with [bookingServerIssuePrefix] came from the server.
  final Map<String, Map<String, String>> travelerErrors;

  /// One-shot: true for exactly the emission after the server accepted the
  /// travelers and quoted them; the UI navigates, then acknowledges.
  final bool reviewReady;

  /// One-shot: the draft was filed on the server without going to the review.
  final bool draftSaved;

  final BookingSyncStatus syncStatus;
  final Failure? syncFailure;

  /// The server's quote of the draft (`portalDraftReview`); null until Continue
  /// succeeded.
  final DraftReview? review;
  final bool reviewLoading;
  final Failure? reviewFailure;

  final BookingSubmissionStatus submissionStatus;
  final Failure? submissionFailure;
  final ServiceBookingResult? submissionResult;

  /// Opened from the drafts list: the travelers are the server's (masked) and
  /// cannot be edited here.
  final bool resumed;

  /// The server-defined traveler form of the service.
  List<DynamicFormField> get travelerFields => service.fields;

  TravelerInfo get activeTraveler => travelers[activeTravelerIndex];

  bool get isSaving => syncStatus == BookingSyncStatus.saving;

  ServiceBookingInProgress copyWith({
    List<TravelerInfo>? travelers,
    int? activeTravelerIndex,
    Map<String, Map<String, String>>? travelerErrors,
    bool? reviewReady,
    bool? draftSaved,
    BookingSyncStatus? syncStatus,
    Failure? syncFailure,
    bool clearSyncFailure = false,
    DraftReview? review,
    bool? reviewLoading,
    Failure? reviewFailure,
    bool clearReviewFailure = false,
    BookingSubmissionStatus? submissionStatus,
    Failure? submissionFailure,
    bool clearSubmissionFailure = false,
    ServiceBookingResult? submissionResult,
  }) =>
      ServiceBookingInProgress(
        service: service,
        travelers: travelers ?? this.travelers,
        activeTravelerIndex: activeTravelerIndex ?? this.activeTravelerIndex,
        travelerErrors: travelerErrors ?? this.travelerErrors,
        reviewReady: reviewReady ?? this.reviewReady,
        draftSaved: draftSaved ?? this.draftSaved,
        syncStatus: syncStatus ?? this.syncStatus,
        syncFailure: clearSyncFailure ? null : (syncFailure ?? this.syncFailure),
        review: review ?? this.review,
        reviewLoading: reviewLoading ?? this.reviewLoading,
        reviewFailure: clearReviewFailure ? null : (reviewFailure ?? this.reviewFailure),
        submissionStatus: submissionStatus ?? this.submissionStatus,
        submissionFailure: clearSubmissionFailure ? null : (submissionFailure ?? this.submissionFailure),
        submissionResult: submissionResult ?? this.submissionResult,
        hospital: hospital,
        resumed: resumed,
      );

  @override
  List<Object?> get props => [
        service,
        travelers,
        activeTravelerIndex,
        travelerErrors,
        reviewReady,
        draftSaved,
        syncStatus,
        syncFailure,
        review,
        reviewLoading,
        reviewFailure,
        submissionStatus,
        submissionFailure,
        submissionResult,
        hospital,
        resumed,
      ];
}
