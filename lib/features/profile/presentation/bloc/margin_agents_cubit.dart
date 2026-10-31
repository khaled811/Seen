import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../agents/domain/entities/sub_agent.dart';
import '../../../agents/domain/usecases/get_sub_agents_usecase.dart';
import 'profile_cubits.dart' show LoadStatus;

class MarginAgentsState extends Equatable {
  const MarginAgentsState({this.status = LoadStatus.loading, this.agents = const [], this.failure});

  final LoadStatus status;
  final List<SubAgent> agents;
  final Failure? failure;

  @override
  List<Object?> get props => [status, agents, failure];
}

/// The sub-agencies a margin can be set for. Margins are per sub-agency, so editing
/// them starts by choosing one. Owner: the picker screen.
class MarginAgentsCubit extends Cubit<MarginAgentsState> {
  MarginAgentsCubit(this._getSubAgents) : super(const MarginAgentsState());

  final GetSubAgentsUseCase _getSubAgents;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      if (state.agents.isEmpty) emit(const MarginAgentsState());
      final result = await _getSubAgents();
      if (isClosed) return;
      result.fold(
        (f) => emit(MarginAgentsState(status: LoadStatus.failure, agents: state.agents, failure: f)),
        // A margin applies to an agency that is already running: pending ones are left out.
        (list) => emit(MarginAgentsState(status: LoadStatus.loaded, agents: [for (final a in list) if (!a.invitePending) a])),
      );
    } finally {
      _loading = false;
    }
  }
}
