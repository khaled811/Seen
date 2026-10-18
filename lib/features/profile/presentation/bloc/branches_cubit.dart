// The branches screen (Figma ACC-07): the tree, the people of one branch, the
// "view requests by branch" scope, and adding / assigning / moving.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/state/branch_scope.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/branch_repository.dart';
import '../../domain/usecases/profile_usecases.dart';
import 'profile_cubits.dart' show LoadStatus;

enum BranchNotice { created, assigned, failed }

class BranchesState extends Equatable {
  const BranchesState({
    this.status = LoadStatus.loading,
    this.branches = const [],
    this.focusId,
    this.staff = const [],
    this.staffLoading = false,
    this.busy = false,
    this.notice,
    this.noticeSeq = 0,
  });

  final LoadStatus status;
  final List<Branch> branches;

  /// The branch whose people are listed.
  final String? focusId;
  final List<BranchStaff> staff;
  final bool staffLoading;
  final bool busy;
  final BranchNotice? notice;
  final int noticeSeq;

  Branch? get focus => branches.where((b) => b.id == focusId).firstOrNull;

  BranchesState copyWith({
    LoadStatus? status,
    List<Branch>? branches,
    String? focusId,
    List<BranchStaff>? staff,
    bool? staffLoading,
    bool? busy,
    BranchNotice? notice,
  }) =>
      BranchesState(
        status: status ?? this.status,
        branches: branches ?? this.branches,
        focusId: focusId ?? this.focusId,
        staff: staff ?? this.staff,
        staffLoading: staffLoading ?? this.staffLoading,
        busy: busy ?? this.busy,
        notice: notice ?? this.notice,
        noticeSeq: notice == null ? noticeSeq : noticeSeq + 1,
      );

  @override
  List<Object?> get props => [status, branches, focusId, staff, staffLoading, busy, notice, noticeSeq];
}

class BranchesCubit extends Cubit<BranchesState> {
  BranchesCubit({required BranchRepository branches, required TeamUseCases team, BranchScope? scope})
      : _branches = branches,
        _team = team,
        scope = scope ?? BranchScope.shared,
        super(const BranchesState());

  final BranchRepository _branches;
  final TeamUseCases _team;

  /// The app-wide "requests of branch" choice; this cubit only writes it.
  final BranchScope scope;

  int _staffRequest = 0;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      if (state.branches.isEmpty) {
        emit(const BranchesState());
      }
      final r = await _branches.list();
      if (isClosed) {
        return;
      }
      await r.fold(
        (_) async => emit(state.copyWith(status: LoadStatus.failure)),
        (list) async {
          // Keep the branch in focus if it still exists, else the first sub-branch (or the main one).
          final keep = list.any((b) => b.id == state.focusId) ? state.focusId : null;
          final first = list.where((b) => !b.isMain).firstOrNull ?? list.firstOrNull;
          emit(state.copyWith(status: LoadStatus.loaded, branches: list, focusId: keep ?? first?.id));
          final id = state.focusId;
          if (id != null) {
            await focus(id);
          }
        },
      );
    } finally {
      _loading = false;
    }
  }

  /// Lists the people of [branchId]; when two taps overlap, the later one wins.
  Future<void> focus(String branchId) async {
    final mine = ++_staffRequest;
    emit(state.copyWith(focusId: branchId, staffLoading: true, staff: const []));
    final r = await _branches.staff(branchId);
    if (isClosed || mine != _staffRequest) {
      return;
    }
    r.fold(
      (_) => emit(state.copyWith(staffLoading: false, notice: BranchNotice.failed)),
      (s) => emit(state.copyWith(staffLoading: false, staff: s)),
    );
  }

  /// `null` = all branches.
  void setScope(String? branchId) => scope.value = branchId;

  Future<void> create(String name) async {
    if (state.busy) {
      return;
    }
    emit(state.copyWith(busy: true));
    final r = await _branches.create(name);
    if (isClosed) {
      return;
    }
    await r.fold(
      (_) async => emit(state.copyWith(busy: false, notice: BranchNotice.failed)),
      (b) async {
        emit(state.copyWith(busy: false, notice: BranchNotice.created));
        await load();
        await focus(b.id);
      },
    );
  }

  /// Members that can be given a branch: everyone but the owner.
  Future<List<TeamMember>> assignableMembers() async {
    final r = await _team.list();
    return r.fold((_) => const <TeamMember>[], (m) => [for (final x in m) if (!x.isOwner) x]);
  }

  Future<void> assign({required String memberId, required String branchId}) async {
    if (state.busy) {
      return;
    }
    emit(state.copyWith(busy: true));
    final r = await _branches.assign(memberId: memberId, branchId: branchId);
    if (isClosed) {
      return;
    }
    await r.fold(
      (_) async => emit(state.copyWith(busy: false, notice: BranchNotice.failed)),
      (_) async {
        emit(state.copyWith(busy: false, notice: BranchNotice.assigned));
        await load();
      },
    );
  }
}
