import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/airline_circular.dart';
import '../../domain/repositories/airline_circular_repository.dart';

enum ApprovalsStatus { loading, loaded, failure }

class ApprovalPickerState extends Equatable {
  const ApprovalPickerState({
    this.status = ApprovalsStatus.loading,
    this.items = const [],
    this.query = '',
    this.selectedId,
  });

  final ApprovalsStatus status;
  final List<ApprovedSecurityRequest> items;
  final String query;
  final String? selectedId;

  /// The approvals matching the search: by reference or by the lead traveler name.
  List<ApprovedSecurityRequest> get visible {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return [
      for (final a in items)
        if (a.reference.toLowerCase().contains(q) ||
            a.leadName.toLowerCase().contains(q))
          a,
    ];
  }

  ApprovedSecurityRequest? get selected =>
      visible.where((a) => a.id == selectedId).firstOrNull;

  @override
  List<Object?> get props => [status, items, query, selectedId];
}

/// The picker of an issued security approval (Figma REQ-15). The newest is pre-selected.
class ApprovalPickerCubit extends Cubit<ApprovalPickerState> {
  ApprovalPickerCubit(this._repository) : super(const ApprovalPickerState());

  final AirlineCircularRepository _repository;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      emit(const ApprovalPickerState());
      final r = await _repository.approvedRequests();
      if (isClosed) return;
      r.fold(
        (_) => emit(const ApprovalPickerState(status: ApprovalsStatus.failure)),
        (list) => emit(ApprovalPickerState(
          status: ApprovalsStatus.loaded,
          items: list,
          selectedId: list.firstOrNull?.id,
        )),
      );
    } finally {
      _loading = false;
    }
  }

  void search(String query) => emit(ApprovalPickerState(
        status: state.status,
        items: state.items,
        query: query,
        selectedId: state.selectedId,
      ));

  void select(String id) => emit(ApprovalPickerState(
        status: state.status,
        items: state.items,
        query: state.query,
        selectedId: id,
      ));
}
