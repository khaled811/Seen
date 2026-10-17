import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/new_sub_agent.dart';
import '../../domain/entities/sub_agent_profile.dart';
import '../../domain/usecases/sub_agent_management_usecases.dart';

sealed class AgentProfileEvent extends Equatable {
  const AgentProfileEvent();

  @override
  List<Object?> get props => [];
}

final class AgentProfileLoadRequested extends AgentProfileEvent {
  const AgentProfileLoadRequested(this.subAgentId);

  final String subAgentId;

  @override
  List<Object?> get props => [subAgentId];
}

/// Suspend ([active] false, with a reason) or reactivate (Figma AGT-03).
final class AgentActiveChangeSubmitted extends AgentProfileEvent {
  const AgentActiveChangeSubmitted({required this.active, this.reason});

  final bool active;
  final String? reason;

  @override
  List<Object?> get props => [active, reason];
}

enum AgentProfileStatus { loading, ready, failed }

enum AgentProfileOutcome { suspended, reactivated, failed }

class AgentProfileState extends Equatable {
  const AgentProfileState({
    this.status = AgentProfileStatus.loading,
    this.profile,
    this.busy = false,
    this.outcome,
    this.outcomeSeq = 0,
    this.offline = false,
  });

  final AgentProfileStatus status;
  final SubAgentProfile? profile;

  /// A suspend / reactivate request is in flight.
  final bool busy;

  /// The last suspend / reactivate result; [outcomeSeq] changes on each one so
  /// the screen can show a message even for two equal results in a row.
  final AgentProfileOutcome? outcome;
  final int outcomeSeq;

  /// The load failed for lack of a connection (vs a server error).
  final bool offline;

  AgentProfileState copyWith({
    AgentProfileStatus? status,
    SubAgentProfile? profile,
    bool? busy,
    AgentProfileOutcome? outcome,
    bool? offline,
  }) =>
      AgentProfileState(
        status: status ?? this.status,
        profile: profile ?? this.profile,
        busy: busy ?? this.busy,
        outcome: outcome ?? this.outcome,
        outcomeSeq: outcome != null ? outcomeSeq + 1 : outcomeSeq,
        offline: offline ?? this.offline,
      );

  @override
  List<Object?> get props =>
      [status, profile, busy, outcome, outcomeSeq, offline];
}

class AgentProfileBloc extends Bloc<AgentProfileEvent, AgentProfileState> {
  AgentProfileBloc({
    required GetSubAgentProfileUseCase getProfile,
    required SetSubAgentActiveUseCase setActive,
  })  : _get = getProfile,
        _setActive = setActive,
        super(const AgentProfileState()) {
    on<AgentProfileLoadRequested>(_onLoad, transformer: restartable());
    on<AgentActiveChangeSubmitted>(_onActive, transformer: droppable());
  }

  final GetSubAgentProfileUseCase _get;
  final SetSubAgentActiveUseCase _setActive;

  Future<void> _onLoad(
      AgentProfileLoadRequested event, Emitter<AgentProfileState> emit) async {
    // A reload keeps what is on screen; only the first load shows the spinner.
    if (state.profile == null) emit(const AgentProfileState());
    final result = await _get(event.subAgentId);
    result.match(
      (failure) => emit(state.profile == null
          ? AgentProfileState(
              status: AgentProfileStatus.failed,
              offline:
                  SubAgentIssue.from(failure).kind == SubAgentIssueKind.offline,
            )
          : state),
      (profile) => emit(AgentProfileState(
          status: AgentProfileStatus.ready, profile: profile)),
    );
  }

  Future<void> _onActive(
      AgentActiveChangeSubmitted event, Emitter<AgentProfileState> emit) async {
    final profile = state.profile;
    if (profile == null) return;
    emit(state.copyWith(busy: true));
    final result = await _setActive(
        subAgentId: profile.agent.id,
        active: event.active,
        reason: event.reason);
    result.match(
      (failure) => emit(
          state.copyWith(busy: false, outcome: AgentProfileOutcome.failed)),
      (agent) => emit(AgentProfileState(
        status: AgentProfileStatus.ready,
        profile: SubAgentProfile(
          agent: agent,
          city: profile.city,
          memberSince: profile.memberSince,
          monthlyRequestCount: profile.monthlyRequestCount,
          inProgressRequestCount: profile.inProgressRequestCount,
          ledger: profile.ledger,
          requests: profile.requests,
        ),
        outcome: event.active
            ? AgentProfileOutcome.reactivated
            : AgentProfileOutcome.suspended,
        outcomeSeq: state.outcomeSeq + 1,
      )),
    );
  }
}
