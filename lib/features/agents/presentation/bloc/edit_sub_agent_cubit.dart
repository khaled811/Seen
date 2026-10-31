import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/update_sub_agent_usecase.dart';

enum EditAgentStatus { idle, submitting, done, failed }

class EditAgentState extends Equatable {
  const EditAgentState({this.status = EditAgentStatus.idle, this.failure});

  final EditAgentStatus status;
  final Failure? failure;

  @override
  List<Object?> get props => [status, failure];
}

/// Edits one sub-agency's name and its owner's name / sign-in e-mail. Only what changed is
/// sent (an empty or unchanged field is left alone); a second tap while it runs is ignored.
/// Owner: the sheet that shows it.
class EditSubAgentCubit extends Cubit<EditAgentState> {
  EditSubAgentCubit(this._update, {required this.agentId, this.currentName = '', this.currentOwnerName = ''}) : super(const EditAgentState());

  final UpdateSubAgentUseCase _update;
  final String agentId;
  final String currentName;
  final String currentOwnerName;

  /// What each field would send: null when blank or the same as now.
  static String? changed(String typed, String current) {
    final v = typed.trim();
    return v.isEmpty || v == current.trim() ? null : v;
  }

  Future<void> submit({required String name, required String ownerName, required String ownerEmail}) async {
    if (state.status == EditAgentStatus.submitting) return;
    final newName = changed(name, currentName);
    final newOwner = changed(ownerName, currentOwnerName);
    final newEmail = ownerEmail.trim().isEmpty ? null : ownerEmail.trim();
    if (newName == null && newOwner == null && newEmail == null) {
      emit(const EditAgentState(status: EditAgentStatus.done)); // nothing to change
      return;
    }
    emit(const EditAgentState(status: EditAgentStatus.submitting));
    final result = await _update(agentId: agentId, name: newName, ownerFullName: newOwner, ownerEmail: newEmail);
    if (isClosed) return;
    emit(result.fold((f) => EditAgentState(status: EditAgentStatus.failed, failure: f), (_) => const EditAgentState(status: EditAgentStatus.done)));
  }
}
