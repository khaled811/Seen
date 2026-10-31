import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/agency_registration.dart';
import '../../domain/usecases/agency_registration_usecases.dart';

/// Where registration is after the form: the password, the terms (which send it), done.
enum RegistrationStep { password, terms, done }

sealed class AgencyRegistrationEvent extends Equatable {
  const AgencyRegistrationEvent();

  @override
  List<Object?> get props => [];
}

/// Password chosen: it is kept in memory only until the terms are accepted.
final class RegistrationPasswordSubmitted extends AgencyRegistrationEvent {
  const RegistrationPasswordSubmitted(this.password);

  final String password;

  // The password is deliberately not part of equality or any state.
  @override
  List<Object?> get props => [password];
}

/// The terms and the privacy policy were accepted: register the agency.
final class RegistrationConsentSubmitted extends AgencyRegistrationEvent {
  const RegistrationConsentSubmitted(this.consent);

  final RegistrationConsent consent;

  @override
  List<Object?> get props => [consent];
}

final class RegistrationBackPressed extends AgencyRegistrationEvent {
  const RegistrationBackPressed();
}

final class RegistrationIssueDismissed extends AgencyRegistrationEvent {
  const RegistrationIssueDismissed();
}

class AgencyRegistrationState extends Equatable {
  const AgencyRegistrationState({this.step = RegistrationStep.password, this.busy = false, this.issue});

  final RegistrationStep step;
  final bool busy;
  final RegistrationIssue? issue;

  AgencyRegistrationState copyWith({
    RegistrationStep? step,
    bool? busy,
    RegistrationIssue? issue,
    bool clearIssue = false,
  }) =>
      AgencyRegistrationState(
        step: step ?? this.step,
        busy: busy ?? this.busy,
        issue: clearIssue ? null : (issue ?? this.issue),
      );

  @override
  List<Object?> get props => [step, busy, issue];
}

class AgencyRegistrationBloc extends Bloc<AgencyRegistrationEvent, AgencyRegistrationState> {
  AgencyRegistrationBloc({required this.draft, required RegisterAgencyUseCase register})
      : _register = register,
        super(const AgencyRegistrationState()) {
    on<RegistrationPasswordSubmitted>(_onPassword);
    // One registration at a time: a second tap while it runs is dropped.
    on<RegistrationConsentSubmitted>(_onConsent, transformer: droppable());
    on<RegistrationBackPressed>(_onBack);
    on<RegistrationIssueDismissed>((event, emit) => emit(state.copyWith(clearIssue: true)));
  }

  /// What the user typed on the form step.
  final AgencyRegistrationDraft draft;

  final RegisterAgencyUseCase _register;

  /// Held only between the password step and the registration call; cleared as
  /// soon as it was sent (or the person goes back). Never in a state.
  String? _password;

  void _onPassword(RegistrationPasswordSubmitted event, Emitter<AgencyRegistrationState> emit) {
    _password = event.password;
    emit(state.copyWith(step: RegistrationStep.terms, clearIssue: true));
  }

  Future<void> _onConsent(RegistrationConsentSubmitted event, Emitter<AgencyRegistrationState> emit) async {
    final password = _password;
    if (password == null || !event.consent.acceptedTerms || !event.consent.acceptedPrivacy) return;
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _register(draft: draft, password: password, consent: event.consent);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RegistrationIssue.from(failure))),
      (_) {
        _password = null;
        emit(state.copyWith(busy: false, step: RegistrationStep.done));
      },
    );
  }

  void _onBack(RegistrationBackPressed event, Emitter<AgencyRegistrationState> emit) {
    switch (state.step) {
      case RegistrationStep.terms:
        _password = null;
        emit(state.copyWith(step: RegistrationStep.password, clearIssue: true));
      case RegistrationStep.password:
      case RegistrationStep.done:
        break;
    }
  }
}
