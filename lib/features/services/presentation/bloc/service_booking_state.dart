import 'package:equatable/equatable.dart';

import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../../wallet/domain/entities/wallet_balance.dart';
import '../../domain/entities/service_booking_result.dart';
import '../../domain/entities/service_definition.dart';
import '../../domain/entities/traveler_info.dart';
import '../../domain/pricing.dart';

enum BookingSubmissionStatus { idle, submitting, success, failure }

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
  const ServiceCatalogFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class ServiceCatalogLoaded extends ServiceBookingState {
  const ServiceCatalogLoaded(this.services);

  final List<ServiceDefinition> services;

  @override
  List<Object?> get props => [services];
}

/// The state of an in-progress booking session: from picking travelers,
/// through review, to submission. One cohesive flow, not a grab-bag — kept
/// as a single state (rather than one class per screen) because every
/// field describes the same ongoing session.
final class ServiceBookingInProgress extends ServiceBookingState {
  const ServiceBookingInProgress({
    required this.service,
    required this.travelerFields,
    required this.travelers,
    required this.activeTravelerIndex,
    this.travelerErrors = const {},
    this.reviewReady = false,
    this.walletBalance,
    this.walletBalanceLoading = false,
    this.submissionStatus = BookingSubmissionStatus.idle,
    this.submissionError,
    this.submissionResult,
    this.draftId,
  });

  final ServiceDefinition service;
  final List<DynamicFormField> travelerFields;
  final List<TravelerInfo> travelers;
  final int activeTravelerIndex;

  /// Traveler id -> field key -> error message. Populated only after a
  /// validation pass (Continue/Submit), not on every keystroke.
  final Map<String, Map<String, String>> travelerErrors;

  /// One-shot: true for exactly the emission after a clean validation pass;
  /// the UI navigates then dispatches `ReviewReadyAcknowledged` to clear it.
  final bool reviewReady;

  final WalletBalance? walletBalance;
  final bool walletBalanceLoading;
  final BookingSubmissionStatus submissionStatus;
  final String? submissionError;
  final ServiceBookingResult? submissionResult;

  /// The saved draft this booking was resumed from (or last saved as), so a
  /// later save overwrites it and a successful submit removes it.
  final String? draftId;

  int get totalPriceCents => ServicePricing.totalPriceCents(
        perPersonPriceCents: service.perPersonPriceCents,
        travelerCount: travelers.length,
      );

  /// `true` when the balance hasn't loaded yet — a UX aid only, never a
  /// substitute for the backend's own enforcement.
  bool get hasSufficientBalance =>
      walletBalance == null || walletBalance!.availableCents >= totalPriceCents;

  TravelerInfo get activeTraveler => travelers[activeTravelerIndex];

  ServiceBookingInProgress copyWith({
    List<TravelerInfo>? travelers,
    int? activeTravelerIndex,
    Map<String, Map<String, String>>? travelerErrors,
    bool? reviewReady,
    WalletBalance? walletBalance,
    bool? walletBalanceLoading,
    BookingSubmissionStatus? submissionStatus,
    String? submissionError,
    bool clearSubmissionError = false,
    ServiceBookingResult? submissionResult,
    String? draftId,
  }) =>
      ServiceBookingInProgress(
        service: service,
        travelerFields: travelerFields,
        travelers: travelers ?? this.travelers,
        activeTravelerIndex: activeTravelerIndex ?? this.activeTravelerIndex,
        travelerErrors: travelerErrors ?? this.travelerErrors,
        reviewReady: reviewReady ?? this.reviewReady,
        walletBalance: walletBalance ?? this.walletBalance,
        walletBalanceLoading: walletBalanceLoading ?? this.walletBalanceLoading,
        submissionStatus: submissionStatus ?? this.submissionStatus,
        submissionError: clearSubmissionError ? null : (submissionError ?? this.submissionError),
        submissionResult: submissionResult ?? this.submissionResult,
        draftId: draftId ?? this.draftId,
      );

  @override
  List<Object?> get props => [
        service,
        travelerFields,
        travelers,
        activeTravelerIndex,
        travelerErrors,
        reviewReady,
        walletBalance,
        walletBalanceLoading,
        submissionStatus,
        submissionError,
        submissionResult,
        draftId,
      ];
}
