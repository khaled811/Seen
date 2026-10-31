// Cubits for changing the password (Figma AUTH-15) and the phone number (AUTH-16).
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/account_security.dart';
import '../../domain/repositories/account_security_repository.dart';

// ───────────────────────── AUTH-15 ─────────────────────────

class ChangePasswordState extends Equatable {
  const ChangePasswordState({this.busy = false, this.done = false, this.issue});

  final bool busy;

  /// The password was changed (and the other devices signed out).
  final bool done;
  final AccountIssue? issue;

  @override
  List<Object?> get props => [busy, done, issue];
}

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  /// [onChanged] runs once the password was changed: the server then signs every
  /// session out (this device included), so the app ends its own session too.
  ChangePasswordCubit(this._repository, {this.onChanged}) : super(const ChangePasswordState());

  final AccountSecurityRepository _repository;
  final void Function()? onChanged;

  /// A second tap while saving is ignored.
  Future<void> submit({required String current, required String next}) async {
    if (state.busy) {
      return;
    }
    emit(const ChangePasswordState(busy: true));
    final result = await _repository.changePassword(current: current, next: next);
    if (isClosed) {
      return;
    }
    result.fold(
      (f) => emit(ChangePasswordState(issue: AccountIssue.from(f))),
      (_) {
        emit(const ChangePasswordState(done: true));
        onChanged?.call();
      },
    );
  }

  /// The user edited a field again: the last answer no longer applies.
  void edited() {
    if (state.issue != null || state.done) {
      emit(const ChangePasswordState());
    }
  }
}

// ───────────────────────── AUTH-16 ─────────────────────────

class ChangePhoneState extends Equatable {
  const ChangePhoneState({
    this.currentMasked,
    this.challenge,
    this.busy = false,
    this.done = false,
    this.issue,
  });

  /// null while loading (or if the server did not say).
  final String? currentMasked;

  /// Set once a code was sent to the new number.
  final PhoneChangeChallenge? challenge;
  final bool busy;
  final bool done;
  final AccountIssue? issue;

  bool get codeSent => challenge != null;

  ChangePhoneState copyWith({
    String? currentMasked,
    PhoneChangeChallenge? challenge,
    bool clearChallenge = false,
    bool? busy,
    bool? done,
    AccountIssue? issue,
    bool clearIssue = false,
  }) =>
      ChangePhoneState(
        currentMasked: currentMasked ?? this.currentMasked,
        challenge: clearChallenge ? null : (challenge ?? this.challenge),
        busy: busy ?? this.busy,
        done: done ?? this.done,
        issue: clearIssue ? null : (issue ?? this.issue),
      );

  @override
  List<Object?> get props => [currentMasked, challenge, busy, done, issue];
}

class ChangePhoneCubit extends Cubit<ChangePhoneState> {
  ChangePhoneCubit(this._repository) : super(const ChangePhoneState());

  final AccountSecurityRepository _repository;

  Future<void> load() async {
    final r = await _repository.currentPhoneMasked();
    if (isClosed) {
      return;
    }
    r.fold((_) {}, (masked) => emit(state.copyWith(currentMasked: masked)));
  }

  /// Sends the code to [newPhone] (E.164). Ignored while another call runs.
  Future<void> sendCode(String newPhone) async {
    if (state.busy) {
      return;
    }
    emit(state.copyWith(busy: true, clearIssue: true));
    final r = await _repository.requestPhoneChange(newPhone);
    if (isClosed) {
      return;
    }
    r.fold(
      (f) => emit(state.copyWith(busy: false, issue: AccountIssue.from(f))),
      (c) => emit(state.copyWith(busy: false, challenge: c)),
    );
  }

  Future<void> resend() async {
    final token = state.challenge?.challengeToken;
    if (token == null || state.busy) {
      return;
    }
    emit(state.copyWith(busy: true, clearIssue: true));
    final r = await _repository.resendPhoneChange(token);
    if (isClosed) {
      return;
    }
    r.fold(
      (f) => emit(state.copyWith(busy: false, issue: AccountIssue.from(f))),
      (c) => emit(state.copyWith(busy: false, challenge: c)),
    );
  }

  Future<void> confirm(String code) async {
    final token = state.challenge?.challengeToken;
    if (token == null || state.busy) {
      return;
    }
    emit(state.copyWith(busy: true, clearIssue: true));
    final r = await _repository.confirmPhoneChange(challengeToken: token, code: code);
    if (isClosed) {
      return;
    }
    r.fold(
      (f) => emit(state.copyWith(busy: false, issue: AccountIssue.from(f))),
      (_) => emit(state.copyWith(busy: false, done: true)),
    );
  }

  /// The number was edited after a code went out: that code was for another number.
  void phoneEdited() {
    if (state.codeSent || state.issue != null) {
      emit(state.copyWith(clearChallenge: true, clearIssue: true));
    }
  }

  void dismissIssue() {
    if (state.issue != null) {
      emit(state.copyWith(clearIssue: true));
    }
  }
}
