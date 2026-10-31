import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/password_recovery.dart';
import '../../domain/usecases/password_recovery_usecases.dart';

/// Where the "forgot password" flow is: asking for the link, then told to open it.
enum RecoveryStep { request, linkSent }

sealed class PasswordRecoveryEvent extends Equatable {
  const PasswordRecoveryEvent();

  @override
  List<Object?> get props => [];
}

final class RecoveryLinkRequested extends PasswordRecoveryEvent {
  const RecoveryLinkRequested(this.email);

  /// The e-mail address of the account (the only way to reset a password).
  final String email;

  @override
  List<Object?> get props => [email];
}

/// "Use another address" on the confirmation: back to the form.
final class RecoveryBackPressed extends PasswordRecoveryEvent {
  const RecoveryBackPressed();
}

final class RecoveryIssueDismissed extends PasswordRecoveryEvent {
  const RecoveryIssueDismissed();
}

class PasswordRecoveryState extends Equatable {
  const PasswordRecoveryState({this.step = RecoveryStep.request, this.busy = false, this.email, this.issue});

  final RecoveryStep step;
  final bool busy;

  /// The address the link was asked for (kept for the confirmation text).
  final String? email;
  final RecoveryIssue? issue;

  PasswordRecoveryState copyWith({
    RecoveryStep? step,
    bool? busy,
    String? email,
    RecoveryIssue? issue,
    bool clearIssue = false,
  }) =>
      PasswordRecoveryState(
        step: step ?? this.step,
        busy: busy ?? this.busy,
        email: email ?? this.email,
        issue: clearIssue ? null : (issue ?? this.issue),
      );

  @override
  List<Object?> get props => [step, busy, email, issue];
}

class PasswordRecoveryBloc extends Bloc<PasswordRecoveryEvent, PasswordRecoveryState> {
  PasswordRecoveryBloc({required RequestPasswordResetUseCase requestReset})
      : _requestReset = requestReset,
        super(const PasswordRecoveryState()) {
    // One request at a time: a second tap while it runs is dropped.
    on<RecoveryLinkRequested>(_onRequested, transformer: droppable());
    on<RecoveryBackPressed>(
      (event, emit) => emit(state.copyWith(step: RecoveryStep.request, clearIssue: true)),
    );
    on<RecoveryIssueDismissed>((event, emit) => emit(state.copyWith(clearIssue: true)));
  }

  final RequestPasswordResetUseCase _requestReset;

  Future<void> _onRequested(RecoveryLinkRequested event, Emitter<PasswordRecoveryState> emit) async {
    final email = event.email.trim();
    // Only an e-mail address can be reset: nothing is sent for anything else.
    if (!email.contains('@')) {
      emit(state.copyWith(issue: const RecoveryIssue(RecoveryIssueKind.emailRequired)));
      return;
    }
    emit(state.copyWith(busy: true, email: email, clearIssue: true));
    final result = await _requestReset(email: email);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RecoveryIssue.from(failure))),
      (_) => emit(state.copyWith(busy: false, step: RecoveryStep.linkSent)),
    );
  }
}
