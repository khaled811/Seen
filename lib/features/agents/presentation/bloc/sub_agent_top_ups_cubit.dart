import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/sub_agent_top_up.dart';
import '../../domain/usecases/sub_agent_top_up_usecases.dart';

enum TopUpsLoad { loading, loaded, failure }

/// How the last decision ended.
enum TopUpDecisionKind { none, approved, rejected, failed }

class TopUpDecisionResult extends Equatable {
  const TopUpDecisionResult({this.kind = TopUpDecisionKind.none, this.failure, this.seq = 0});

  final TopUpDecisionKind kind;
  final Failure? failure;

  /// Changes on every result so the screen reacts once per attempt.
  final int seq;

  @override
  List<Object?> get props => [kind, failure, seq];
}

class SubAgentTopUpsState extends Equatable {
  const SubAgentTopUpsState({
    this.load = TopUpsLoad.loading,
    this.items = const [],
    this.busyId,
    this.failure,
    this.decision = const TopUpDecisionResult(),
  });

  final TopUpsLoad load;
  final List<SubAgentTopUp> items;

  /// The request a decision is running on (its row is inert; no other can start).
  final String? busyId;
  final Failure? failure;
  final TopUpDecisionResult decision;

  SubAgentTopUpsState copyWith({
    TopUpsLoad? load,
    List<SubAgentTopUp>? items,
    String? busyId,
    bool clearBusy = false,
    Failure? failure,
    TopUpDecisionResult? decision,
  }) =>
      SubAgentTopUpsState(
        load: load ?? this.load,
        items: items ?? this.items,
        busyId: clearBusy ? null : (busyId ?? this.busyId),
        failure: failure,
        decision: decision ?? this.decision,
      );

  @override
  List<Object?> get props => [load, items, busyId, failure, decision];
}

/// The funding requests of the sub-agencies that wait for this main agent. One decision at
/// a time; approving moves money, so a second tap while one runs is ignored, and after a
/// lost connection the list is read again (the request may or may not have been decided).
/// Owner: the approvals screen.
class SubAgentTopUpsCubit extends Cubit<SubAgentTopUpsState> {
  SubAgentTopUpsCubit(this._uc) : super(const SubAgentTopUpsState());

  final SubAgentTopUpUseCases _uc;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final result = await _uc.pending();
      if (isClosed) return;
      result.fold(
        (f) => emit(state.copyWith(load: TopUpsLoad.failure, failure: f)),
        (items) => emit(state.copyWith(load: TopUpsLoad.loaded, items: items)),
      );
    } finally {
      _loading = false;
    }
  }

  Future<void> approve(String id) => _decide(id, approve: true, note: '');

  Future<void> reject(String id, {String note = ''}) => _decide(id, approve: false, note: note);

  Future<void> _decide(String id, {required bool approve, required String note}) async {
    if (state.busyId != null || !state.items.any((t) => t.id == id)) return;
    emit(state.copyWith(busyId: id));
    final result = approve ? await _uc.approve(id) : await _uc.reject(id, note: note);
    if (isClosed) return;
    final seq = state.decision.seq + 1;
    var lostConnection = false;
    result.fold(
      (f) {
        lostConnection = f is NetworkFailure;
        emit(state.copyWith(clearBusy: true, decision: TopUpDecisionResult(kind: TopUpDecisionKind.failed, failure: f, seq: seq)));
      },
      (_) => emit(state.copyWith(
        clearBusy: true,
        items: [for (final t in state.items) if (t.id != id) t],
        decision: TopUpDecisionResult(kind: approve ? TopUpDecisionKind.approved : TopUpDecisionKind.rejected, seq: seq),
      )),
    );
    // An unanswered decision may have gone through: the server's list is the truth.
    if (lostConnection) await load();
  }
}
