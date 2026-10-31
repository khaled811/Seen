import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/new_sub_agent.dart';
import '../../domain/entities/sub_agent.dart';
import '../../domain/usecases/sub_agent_management_usecases.dart';

// ------------------------------------------------------------ add sub-agent

sealed class AddSubAgentEvent extends Equatable {
  const AddSubAgentEvent();

  @override
  List<Object?> get props => [];
}

final class AddSubAgentSubmitted extends AddSubAgentEvent {
  const AddSubAgentSubmitted(this.newSubAgent);

  final NewSubAgent newSubAgent;

  @override
  List<Object?> get props => [newSubAgent];
}

final class AddSubAgentIssueDismissed extends AddSubAgentEvent {
  const AddSubAgentIssueDismissed();
}

/// Back to an empty form after a success ("add another").
final class AddSubAgentReset extends AddSubAgentEvent {
  const AddSubAgentReset();
}

class AddSubAgentState extends Equatable {
  const AddSubAgentState({this.submitting = false, this.created, this.issue});

  final bool submitting;

  /// Set once the sub-agent exists (the success page).
  final SubAgent? created;
  final SubAgentIssue? issue;

  @override
  List<Object?> get props => [submitting, created, issue];
}

class AddSubAgentBloc extends Bloc<AddSubAgentEvent, AddSubAgentState> {
  AddSubAgentBloc({required CreateSubAgentUseCase createSubAgent})
      : _create = createSubAgent,
        super(const AddSubAgentState()) {
    on<AddSubAgentSubmitted>(_onSubmitted, transformer: droppable());
    on<AddSubAgentIssueDismissed>(
        (event, emit) => emit(AddSubAgentState(created: state.created)));
    on<AddSubAgentReset>((event, emit) => emit(const AddSubAgentState()));
  }

  final CreateSubAgentUseCase _create;

  Future<void> _onSubmitted(
      AddSubAgentSubmitted event, Emitter<AddSubAgentState> emit) async {
    emit(const AddSubAgentState(submitting: true));
    final result = await _create(event.newSubAgent);
    result.match(
      (failure) => emit(AddSubAgentState(issue: SubAgentIssue.from(failure))),
      (agent) => emit(AddSubAgentState(created: agent)),
    );
  }
}
