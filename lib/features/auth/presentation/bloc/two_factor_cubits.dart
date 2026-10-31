// Two-step verification (Figma SEC-01..04): the status shown in Settings and the flow that
// turns it on or issues new recovery codes. Secrets and codes live only in these states.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/two_factor.dart';
import '../../domain/repositories/two_factor_repository.dart';

// ───────────────────────── SEC-01 ─────────────────────────

class TwoFactorStatusState extends Equatable {
  const TwoFactorStatusState({this.loading = true, this.status, this.failed = false});

  final bool loading;
  final TwoFactorStatus? status;

  /// The status could not be read; the rest of Settings stays usable.
  final bool failed;

  @override
  List<Object?> get props => [loading, status, failed];
}

class TwoFactorStatusCubit extends Cubit<TwoFactorStatusState> {
  TwoFactorStatusCubit(this._repository) : super(const TwoFactorStatusState());

  final TwoFactorRepository _repository;

  Future<void> load() async {
    emit(const TwoFactorStatusState());
    final result = await _repository.status();
    if (isClosed) {
      return;
    }
    result.fold(
      (_) => emit(const TwoFactorStatusState(loading: false, failed: true)),
      (s) => emit(TwoFactorStatusState(loading: false, status: s)),
    );
  }
}

// ───────────────────────── SEC-02..04 ─────────────────────────

/// `enable` starts with the QR; `regenerate` starts at the code (the user already has a device).
enum TwoFactorFlowMode { enable, regenerate }

enum TwoFactorStep { scan, code, codes }

class TwoFactorFlowState extends Equatable {
  const TwoFactorFlowState({
    required this.step,
    this.loadingSetup = false,
    this.setup,
    this.setupFailed = false,
    this.verifying = false,
    this.issue,
    this.codes = const [],
  });

  final TwoFactorStep step;
  final bool loadingSetup;
  final TwoFactorSetup? setup;
  final bool setupFailed;
  final bool verifying;
  final TwoFactorIssue? issue;

  /// The recovery codes, shown once on the last step.
  final List<String> codes;

  /// Five wrong tries locks the input for a while (`too_many_attempts`).
  bool get locked => issue?.kind == TwoFactorIssueKind.rateLimited;

  TwoFactorFlowState copyWith({
    TwoFactorStep? step,
    bool? loadingSetup,
    TwoFactorSetup? setup,
    bool? setupFailed,
    bool? verifying,
    TwoFactorIssue? issue,
    bool clearIssue = false,
    List<String>? codes,
  }) =>
      TwoFactorFlowState(
        step: step ?? this.step,
        loadingSetup: loadingSetup ?? this.loadingSetup,
        setup: setup ?? this.setup,
        setupFailed: setupFailed ?? this.setupFailed,
        verifying: verifying ?? this.verifying,
        issue: clearIssue ? null : (issue ?? this.issue),
        codes: codes ?? this.codes,
      );

  @override
  List<Object?> get props => [step, loadingSetup, setup, setupFailed, verifying, issue, codes];
}

class TwoFactorFlowCubit extends Cubit<TwoFactorFlowState> {
  TwoFactorFlowCubit(this._repository, {required this.mode})
      : super(TwoFactorFlowState(step: mode == TwoFactorFlowMode.enable ? TwoFactorStep.scan : TwoFactorStep.code));

  final TwoFactorRepository _repository;
  final TwoFactorFlowMode mode;

  /// Reads the secret to scan. Safe to call again for "try again"; leaving the flow simply
  /// drops the unconfirmed secret (the server clears it on the next start).
  Future<void> start() async {
    if (mode != TwoFactorFlowMode.enable || state.loadingSetup) {
      return;
    }
    emit(state.copyWith(loadingSetup: true, setupFailed: false));
    final result = await _repository.begin();
    if (isClosed) {
      return;
    }
    result.fold(
      (_) => emit(state.copyWith(loadingSetup: false, setupFailed: true)),
      (setup) => emit(state.copyWith(loadingSetup: false, setup: setup)),
    );
  }

  void toCode() {
    if (state.setup != null) {
      emit(state.copyWith(step: TwoFactorStep.code, clearIssue: true));
    }
  }

  /// A second submit while one is running is ignored.
  Future<void> submit(String code) async {
    if (state.verifying || state.locked) {
      return;
    }
    emit(state.copyWith(verifying: true, clearIssue: true));
    final result = mode == TwoFactorFlowMode.enable ? await _repository.confirm(code) : await _repository.regenerateRecoveryCodes(code);
    if (isClosed) {
      return;
    }
    result.fold(
      (f) => emit(state.copyWith(verifying: false, issue: TwoFactorIssue.from(f))),
      (codes) => emit(state.copyWith(verifying: false, step: TwoFactorStep.codes, codes: codes)),
    );
  }

  /// The user typed again: the last answer no longer applies (a lock stays).
  void edited() {
    if (state.issue != null && !state.locked) {
      emit(state.copyWith(clearIssue: true));
    }
  }
}
