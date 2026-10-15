import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/agency_registration.dart';
import '../../domain/usecases/agency_registration_usecases.dart';

/// Where registration is after the form (AUTH-05 → 06 → 07 in Figma).
enum RegistrationStep { password, otp, terms, done }

sealed class AgencyRegistrationEvent extends Equatable {
  const AgencyRegistrationEvent();

  @override
  List<Object?> get props => [];
}

/// Password chosen: store the pending registration and text the phone code.
final class RegistrationPasswordSubmitted extends AgencyRegistrationEvent {
  const RegistrationPasswordSubmitted(this.password);

  final String password;

  // The password is deliberately not part of equality or any state.
  @override
  List<Object?> get props => [password];
}

final class RegistrationCodeSubmitted extends AgencyRegistrationEvent {
  const RegistrationCodeSubmitted(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

final class RegistrationResendRequested extends AgencyRegistrationEvent {
  const RegistrationResendRequested();
}

final class RegistrationConsentSubmitted extends AgencyRegistrationEvent {
  const RegistrationConsentSubmitted(this.consent);

  final RegistrationConsent consent;

  @override
  List<Object?> get props => [consent];
}

/// One step back (terms → otp is not allowed once the phone is verified, so
/// terms and otp both return to the password step).
final class RegistrationBackPressed extends AgencyRegistrationEvent {
  const RegistrationBackPressed();
}

final class RegistrationIssueDismissed extends AgencyRegistrationEvent {
  const RegistrationIssueDismissed();
}

class AgencyRegistrationState extends Equatable {
  const AgencyRegistrationState({
    this.step = RegistrationStep.password,
    this.busy = false,
    this.challenge,
    this.codesSent = 0,
    this.verificationToken,
    this.issue,
  });

  final RegistrationStep step;
  final bool busy;
  final RegistrationChallenge? challenge;

  /// Increments on every code sent so the screen can restart its countdown.
  final int codesSent;
  final String? verificationToken;
  final RegistrationIssue? issue;

  AgencyRegistrationState copyWith({
    RegistrationStep? step,
    bool? busy,
    RegistrationChallenge? challenge,
    int? codesSent,
    String? verificationToken,
    RegistrationIssue? issue,
    bool clearIssue = false,
  }) =>
      AgencyRegistrationState(
        step: step ?? this.step,
        busy: busy ?? this.busy,
        challenge: challenge ?? this.challenge,
        codesSent: codesSent ?? this.codesSent,
        verificationToken: verificationToken ?? this.verificationToken,
        issue: clearIssue ? null : (issue ?? this.issue),
      );

  @override
  List<Object?> get props => [step, busy, challenge, codesSent, verificationToken, issue];
}

class AgencyRegistrationBloc extends Bloc<AgencyRegistrationEvent, AgencyRegistrationState> {
  AgencyRegistrationBloc({
    required this.draft,
    required StartAgencyRegistrationUseCase start,
    required ResendRegistrationCodeUseCase resendCode,
    required VerifyRegistrationPhoneUseCase verifyPhone,
    required CompleteAgencyRegistrationUseCase complete,
  })  : _start = start,
        _resendCode = resendCode,
        _verifyPhone = verifyPhone,
        _complete = complete,
        super(const AgencyRegistrationState()) {
    on<RegistrationPasswordSubmitted>(_onPassword, transformer: droppable());
    on<RegistrationCodeSubmitted>(_onCode, transformer: droppable());
    on<RegistrationResendRequested>(_onResend, transformer: droppable());
    on<RegistrationConsentSubmitted>(_onConsent, transformer: droppable());
    on<RegistrationBackPressed>(_onBack);
    on<RegistrationIssueDismissed>((event, emit) => emit(state.copyWith(clearIssue: true)));
  }

  /// What the user typed on the form step.
  final AgencyRegistrationDraft draft;

  final StartAgencyRegistrationUseCase _start;
  final ResendRegistrationCodeUseCase _resendCode;
  final VerifyRegistrationPhoneUseCase _verifyPhone;
  final CompleteAgencyRegistrationUseCase _complete;

  Future<void> _onPassword(RegistrationPasswordSubmitted event, Emitter<AgencyRegistrationState> emit) async {
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _start(draft: draft, password: event.password);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RegistrationIssue.from(failure))),
      (challenge) => emit(state.copyWith(
        busy: false,
        step: RegistrationStep.otp,
        challenge: challenge,
        codesSent: state.codesSent + 1,
      )),
    );
  }

  Future<void> _onResend(RegistrationResendRequested event, Emitter<AgencyRegistrationState> emit) async {
    final challenge = state.challenge;
    if (challenge == null) return;
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _resendCode(challengeToken: challenge.challengeToken);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RegistrationIssue.from(failure))),
      (next) => emit(state.copyWith(busy: false, challenge: next, codesSent: state.codesSent + 1)),
    );
  }

  Future<void> _onCode(RegistrationCodeSubmitted event, Emitter<AgencyRegistrationState> emit) async {
    final challenge = state.challenge;
    if (challenge == null) return;
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _verifyPhone(challengeToken: challenge.challengeToken, code: event.code);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RegistrationIssue.from(failure))),
      (token) => emit(state.copyWith(busy: false, step: RegistrationStep.terms, verificationToken: token)),
    );
  }

  Future<void> _onConsent(RegistrationConsentSubmitted event, Emitter<AgencyRegistrationState> emit) async {
    final token = state.verificationToken;
    if (token == null || !event.consent.acceptedTerms || !event.consent.acceptedPrivacy) return;
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _complete(verificationToken: token, consent: event.consent);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RegistrationIssue.from(failure))),
      (_) => emit(state.copyWith(busy: false, step: RegistrationStep.done)),
    );
  }

  void _onBack(RegistrationBackPressed event, Emitter<AgencyRegistrationState> emit) {
    switch (state.step) {
      case RegistrationStep.otp:
        emit(state.copyWith(step: RegistrationStep.password, clearIssue: true));
      case RegistrationStep.terms:
        // The phone is verified; going back to the code would re-ask for it,
        // so the terms step returns to the password step and starts over.
        emit(state.copyWith(step: RegistrationStep.password, clearIssue: true));
      case RegistrationStep.password:
      case RegistrationStep.done:
        break;
    }
  }
}
