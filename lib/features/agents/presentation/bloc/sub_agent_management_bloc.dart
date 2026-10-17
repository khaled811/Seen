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

// ------------------------------------------------------------- credit limit

sealed class CreditLimitEvent extends Equatable {
  const CreditLimitEvent();

  @override
  List<Object?> get props => [];
}

final class CreditLimitSubmitted extends CreditLimitEvent {
  const CreditLimitSubmitted(
      {required this.subAgentId, required this.limitCents});

  final String subAgentId;
  final int limitCents;

  @override
  List<Object?> get props => [subAgentId, limitCents];
}

class CreditLimitState extends Equatable {
  const CreditLimitState({this.submitting = false, this.updated, this.issue});

  final bool submitting;
  final SubAgent? updated;
  final SubAgentIssue? issue;

  @override
  List<Object?> get props => [submitting, updated, issue];
}

class CreditLimitBloc extends Bloc<CreditLimitEvent, CreditLimitState> {
  CreditLimitBloc({required UpdateCreditLimitUseCase updateCreditLimit})
      : _update = updateCreditLimit,
        super(const CreditLimitState()) {
    on<CreditLimitSubmitted>(_onSubmitted, transformer: droppable());
  }

  final UpdateCreditLimitUseCase _update;

  Future<void> _onSubmitted(
      CreditLimitSubmitted event, Emitter<CreditLimitState> emit) async {
    emit(const CreditLimitState(submitting: true));
    final result = await _update(
        subAgentId: event.subAgentId, limitCents: event.limitCents);
    result.match(
      (failure) => emit(CreditLimitState(issue: SubAgentIssue.from(failure))),
      (agent) => emit(CreditLimitState(updated: agent)),
    );
  }
}
