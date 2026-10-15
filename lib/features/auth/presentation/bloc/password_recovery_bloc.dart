import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/password_recovery.dart';
import '../../domain/usecases/password_recovery_usecases.dart';

/// Where the "forgot password" flow is (AUTH-01 → 02 → 03 → 04 in Figma).
enum RecoveryStep { request, otp, newPassword, done }

sealed class PasswordRecoveryEvent extends Equatable {
  const PasswordRecoveryEvent();

  @override
  List<Object?> get props => [];
}

final class RecoveryCodeRequested extends PasswordRecoveryEvent {
  const RecoveryCodeRequested(this.identifier);

  /// Login identifier: an E.164 phone number or an email.
  final String identifier;

  @override
  List<Object?> get props => [identifier];
}

final class RecoveryCodeSubmitted extends PasswordRecoveryEvent {
  const RecoveryCodeSubmitted(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

final class RecoveryResendRequested extends PasswordRecoveryEvent {
  const RecoveryResendRequested();
}

final class RecoveryPasswordSubmitted extends PasswordRecoveryEvent {
  const RecoveryPasswordSubmitted(this.newPassword);

  final String newPassword;

  @override
  List<Object?> get props => [newPassword];
}

/// One step back (OTP → request, new password → request). The flow screen
/// leaves the flow itself when it is already on the first step.
final class RecoveryBackPressed extends PasswordRecoveryEvent {
  const RecoveryBackPressed();
}

final class RecoveryIssueDismissed extends PasswordRecoveryEvent {
  const RecoveryIssueDismissed();
}

class PasswordRecoveryState extends Equatable {
  const PasswordRecoveryState({
    this.step = RecoveryStep.request,
    this.busy = false,
    this.identifier,
    this.challenge,
    this.codesSent = 0,
    this.resetToken,
    this.issue,
  });

  final RecoveryStep step;
  final bool busy;

  /// What the user asked a code for; kept so "retry" can resend the request.
  final String? identifier;
  final RecoveryChallenge? challenge;

  /// Increments on every code sent (request or resend) so the screen can
  /// restart its resend countdown.
  final int codesSent;
  final String? resetToken;
  final RecoveryIssue? issue;

  PasswordRecoveryState copyWith({
    RecoveryStep? step,
    bool? busy,
    String? identifier,
    RecoveryChallenge? challenge,
    int? codesSent,
    String? resetToken,
    RecoveryIssue? issue,
    bool clearIssue = false,
  }) =>
      PasswordRecoveryState(
        step: step ?? this.step,
        busy: busy ?? this.busy,
        identifier: identifier ?? this.identifier,
        challenge: challenge ?? this.challenge,
        codesSent: codesSent ?? this.codesSent,
        resetToken: resetToken ?? this.resetToken,
        issue: clearIssue ? null : (issue ?? this.issue),
      );

  @override
  List<Object?> get props => [step, busy, identifier, challenge, codesSent, resetToken, issue];
}

class PasswordRecoveryBloc extends Bloc<PasswordRecoveryEvent, PasswordRecoveryState> {
  PasswordRecoveryBloc({
    required RequestPasswordResetCodeUseCase requestCode,
    required ResendPasswordResetCodeUseCase resendCode,
    required VerifyPasswordResetCodeUseCase verifyCode,
    required ResetPasswordUseCase resetPassword,
  })  : _requestCode = requestCode,
        _resendCode = resendCode,
        _verifyCode = verifyCode,
        _resetPassword = resetPassword,
        super(const PasswordRecoveryState()) {
    on<RecoveryCodeRequested>(_onRequested, transformer: droppable());
    on<RecoveryCodeSubmitted>(_onSubmitted, transformer: droppable());
    on<RecoveryResendRequested>(_onResend, transformer: droppable());
    on<RecoveryPasswordSubmitted>(_onPassword, transformer: droppable());
    on<RecoveryBackPressed>(_onBack);
    on<RecoveryIssueDismissed>((event, emit) => emit(state.copyWith(clearIssue: true)));
  }

  final RequestPasswordResetCodeUseCase _requestCode;
  final ResendPasswordResetCodeUseCase _resendCode;
  final VerifyPasswordResetCodeUseCase _verifyCode;
  final ResetPasswordUseCase _resetPassword;

  Future<void> _onRequested(RecoveryCodeRequested event, Emitter<PasswordRecoveryState> emit) async {
    emit(state.copyWith(busy: true, identifier: event.identifier, clearIssue: true));
    final result = await _requestCode(identifier: event.identifier);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RecoveryIssue.from(failure))),
      (challenge) => emit(state.copyWith(
        busy: false,
        step: RecoveryStep.otp,
        challenge: challenge,
        codesSent: state.codesSent + 1,
      )),
    );
  }

  Future<void> _onResend(RecoveryResendRequested event, Emitter<PasswordRecoveryState> emit) async {
    final challenge = state.challenge;
    if (challenge == null) return;
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _resendCode(challengeToken: challenge.challengeToken);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RecoveryIssue.from(failure))),
      (next) => emit(state.copyWith(busy: false, challenge: next, codesSent: state.codesSent + 1)),
    );
  }

  Future<void> _onSubmitted(RecoveryCodeSubmitted event, Emitter<PasswordRecoveryState> emit) async {
    final challenge = state.challenge;
    if (challenge == null) return;
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _verifyCode(challengeToken: challenge.challengeToken, code: event.code);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RecoveryIssue.from(failure))),
      (token) => emit(state.copyWith(busy: false, step: RecoveryStep.newPassword, resetToken: token)),
    );
  }

  Future<void> _onPassword(RecoveryPasswordSubmitted event, Emitter<PasswordRecoveryState> emit) async {
    final token = state.resetToken;
    if (token == null) return;
    emit(state.copyWith(busy: true, clearIssue: true));
    final result = await _resetPassword(resetToken: token, newPassword: event.newPassword);
    result.match(
      (failure) => emit(state.copyWith(busy: false, issue: RecoveryIssue.from(failure))),
      (_) => emit(state.copyWith(busy: false, step: RecoveryStep.done)),
    );
  }

  void _onBack(RecoveryBackPressed event, Emitter<PasswordRecoveryState> emit) {
    switch (state.step) {
      case RecoveryStep.otp:
      case RecoveryStep.newPassword:
        emit(state.copyWith(step: RecoveryStep.request, clearIssue: true));
      case RecoveryStep.request:
      case RecoveryStep.done:
        break;
    }
  }
}
