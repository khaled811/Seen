import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/enums.dart';
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
/// The server confirmed a transfer to / from this agency: the screen shows it at once, ahead of
/// the next read of the profile (which replaces it with the server's own line).
final class AgentLedgerMoved extends AgentProfileEvent {
  const AgentLedgerMoved({required this.amountCents, required this.isCredit});

  final int amountCents;

  /// true = money went into this agency (a transfer), false = it was taken back.
  final bool isCredit;

  @override
  List<Object?> get props => [amountCents, isCredit];
}

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
    this.refreshing = false,
    this.outcome,
    this.outcomeSeq = 0,
    this.offline = false,
  });

  final AgentProfileStatus status;
  final SubAgentProfile? profile;

  /// A suspend / reactivate request is in flight.
  final bool busy;

  /// The profile is being read again (after a transfer, say) while the old one stays on screen.
  final bool refreshing;

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
    bool? refreshing,
    AgentProfileOutcome? outcome,
    bool? offline,
  }) =>
      AgentProfileState(
        status: status ?? this.status,
        profile: profile ?? this.profile,
        busy: busy ?? this.busy,
        refreshing: refreshing ?? this.refreshing,
        outcome: outcome ?? this.outcome,
        outcomeSeq: outcome != null ? outcomeSeq + 1 : outcomeSeq,
        offline: offline ?? this.offline,
      );

  @override
  List<Object?> get props =>
      [status, profile, busy, refreshing, outcome, outcomeSeq, offline];
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
    on<AgentLedgerMoved>(_onMoved);
  }

  final GetSubAgentProfileUseCase _get;
  final SetSubAgentActiveUseCase _setActive;

  Future<void> _onLoad(
      AgentProfileLoadRequested event, Emitter<AgentProfileState> emit) async {
    // A reload keeps what is on screen; only the first load shows the spinner.
    if (state.profile == null) {
      emit(const AgentProfileState());
    } else {
      emit(state.copyWith(refreshing: true));
    }
    final result = await _get(event.subAgentId);
    result.match(
      (failure) => emit(state.profile == null
          ? AgentProfileState(
              status: AgentProfileStatus.failed,
              offline:
                  SubAgentIssue.from(failure).kind == SubAgentIssueKind.offline,
            )
          : state.copyWith(refreshing: false)),
      (profile) => emit(AgentProfileState(
          status: AgentProfileStatus.ready, profile: _keepPending(profile))),
    );
  }

  /// A line shown ahead of the server (see [AgentLedgerMoved]) stays until the server's own list
  /// has the same movement, so a slow ledger never makes it vanish and come back.
  SubAgentProfile _keepPending(SubAgentProfile fresh) {
    final pending = [
      for (final e in state.profile?.ledger ?? const <AgentLedgerEntry>[])
        if (e.id.startsWith('local-') &&
            !fresh.ledger.any((s) =>
                s.amountCents == e.amountCents &&
                s.isCredit == e.isCredit &&
                s.createdAt.isAfter(e.createdAt.subtract(const Duration(minutes: 2)))))
          e,
    ];
    if (pending.isEmpty) return fresh;
    return SubAgentProfile(
      agent: fresh.agent,
      city: fresh.city,
      memberSince: fresh.memberSince,
      monthlyRequestCount: fresh.monthlyRequestCount,
      inProgressRequestCount: fresh.inProgressRequestCount,
      ledger: [...pending, ...fresh.ledger],
      requests: fresh.requests,
    );
  }

  void _onMoved(AgentLedgerMoved event, Emitter<AgentProfileState> emit) {
    final profile = state.profile;
    if (profile == null || event.amountCents <= 0) return;
    final agent = profile.agent;
    final entry = AgentLedgerEntry(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      type: event.isCredit ? TransactionType.refund : TransactionType.settlement,
      amountCents: event.amountCents,
      isCredit: event.isCredit,
      createdAt: DateTime.now(),
    );
    emit(state.copyWith(
      profile: SubAgentProfile(
        agent: agent.balanceKnown
            ? agent.copyWith(balanceCents: agent.balanceCents + (event.isCredit ? event.amountCents : -event.amountCents))
            : agent,
        city: profile.city,
        memberSince: profile.memberSince,
        monthlyRequestCount: profile.monthlyRequestCount,
        inProgressRequestCount: profile.inProgressRequestCount,
        ledger: [entry, ...profile.ledger],
        requests: profile.requests,
      ),
    ));
  }

  Future<void> _onActive(
      AgentActiveChangeSubmitted event, Emitter<AgentProfileState> emit) async {
    final profile = state.profile;
    if (profile == null) return;
    emit(state.copyWith(busy: true));
    final result = await _setActive(subAgentId: profile.agent.id, active: event.active);
    result.match(
      (failure) => emit(
          state.copyWith(busy: false, outcome: AgentProfileOutcome.failed)),
      (_) => emit(AgentProfileState(
        status: AgentProfileStatus.ready,
        profile: SubAgentProfile(
          // The server confirmed the change; the other figures stay as read.
          agent: profile.agent.copyWith(isActive: event.active, invitePending: false),
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
