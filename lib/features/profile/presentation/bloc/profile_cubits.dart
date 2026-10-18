// Cubits for the account screens (Figma ACC-01 agency, ACC-02 margins, ACC-03 team).
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/agency_profile.dart';
import '../../domain/entities/service_margin.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/usecases/profile_usecases.dart';

enum LoadStatus { loading, loaded, failure }

// ───────────────────────── ACC-01 ─────────────────────────

class AgencyDetailsState extends Equatable {
  const AgencyDetailsState({this.status = LoadStatus.loading, this.profile, this.failure});

  final LoadStatus status;
  final AgencyProfile? profile;
  final Failure? failure;

  @override
  List<Object?> get props => [status, profile, failure];
}

class AgencyDetailsCubit extends Cubit<AgencyDetailsState> {
  AgencyDetailsCubit(this._get) : super(const AgencyDetailsState());

  final GetAgencyProfileUseCase _get;
  bool _busy = false;

  Future<void> load() async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      // A refresh keeps what is on screen; only the first load shows the loader.
      if (state.profile == null) {
        emit(const AgencyDetailsState());
      }
      final result = await _get();
      if (isClosed) {
        return;
      }
      result.fold(
        (f) => emit(AgencyDetailsState(status: LoadStatus.failure, profile: state.profile, failure: f)),
        (p) => emit(AgencyDetailsState(status: LoadStatus.loaded, profile: p)),
      );
    } finally {
      _busy = false;
    }
  }
}

// ───────────────────────── ACC-02 ─────────────────────────

enum MarginSaveStatus { idle, saving, saved, failed }

class MarginsState extends Equatable {
  const MarginsState({
    this.status = LoadStatus.loading,
    this.margins = const [],
    this.history = const [],
    this.drafts = const {},
    this.save = MarginSaveStatus.idle,
    this.failure,
  });

  final LoadStatus status;
  final List<ServiceMargin> margins;
  final List<MarginChange> history;

  /// Unsaved edits: service id -> new value.
  final Map<String, int> drafts;
  final MarginSaveStatus save;
  final Failure? failure;

  bool get dirty => drafts.isNotEmpty;

  /// The value shown for [m]: the draft when edited.
  int valueOf(ServiceMargin m) => drafts[m.serviceId] ?? m.value;

  MarginsState copyWith({
    LoadStatus? status,
    List<ServiceMargin>? margins,
    List<MarginChange>? history,
    Map<String, int>? drafts,
    MarginSaveStatus? save,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      MarginsState(
        status: status ?? this.status,
        margins: margins ?? this.margins,
        history: history ?? this.history,
        drafts: drafts ?? this.drafts,
        save: save ?? this.save,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [status, margins, history, drafts, save, failure];
}

class MarginsCubit extends Cubit<MarginsState> {
  MarginsCubit({required GetMarginsUseCase get, required SaveMarginsUseCase save, this.canEdit = true})
      : _get = get,
        _save = save,
        super(const MarginsState());

  final GetMarginsUseCase _get;
  final SaveMarginsUseCase _save;

  /// false = the signed-in user may only look (not the owner).
  final bool canEdit;

  bool _loading = false;

  Future<void> load() async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      if (state.margins.isEmpty) {
        emit(const MarginsState());
      }
      final result = await _get();
      if (isClosed) {
        return;
      }
      result.fold(
        (f) => emit(state.copyWith(status: LoadStatus.failure, failure: f)),
        (o) => emit(MarginsState(status: LoadStatus.loaded, margins: o.margins, history: o.history, drafts: state.drafts)),
      );
    } finally {
      _loading = false;
    }
  }

  /// Sets [serviceId]'s margin; setting it back to the saved value drops the edit.
  void edit(String serviceId, int value) {
    if (!canEdit || state.save == MarginSaveStatus.saving) {
      return;
    }
    final m = state.margins.where((x) => x.serviceId == serviceId).firstOrNull;
    if (m == null || !m.editable) {
      return;
    }
    final drafts = {...state.drafts};
    if (value == m.value) {
      drafts.remove(serviceId);
    } else {
      drafts[serviceId] = value;
    }
    emit(state.copyWith(drafts: drafts, save: MarginSaveStatus.idle, clearFailure: true));
  }

  /// Sends the edits. A second tap while saving is ignored; the server's answer
  /// replaces what is shown.
  Future<void> save() async {
    if (!state.dirty || state.save == MarginSaveStatus.saving) {
      return;
    }
    emit(state.copyWith(save: MarginSaveStatus.saving, clearFailure: true));
    final result = await _save(state.drafts);
    if (isClosed) {
      return;
    }
    result.fold(
      (f) => emit(state.copyWith(save: MarginSaveStatus.failed, failure: f)),
      (o) => emit(MarginsState(
          status: LoadStatus.loaded, margins: o.margins, history: o.history, save: MarginSaveStatus.saved)),
    );
  }
}

// ───────────────────────── ACC-03 ─────────────────────────

/// One-shot outcome of a team action, for a snack bar.
enum TeamNotice { invited, roleChanged, disabled, reactivated, inviteResent, inviteCancelled, failed }

class TeamState extends Equatable {
  const TeamState({
    this.status = LoadStatus.loading,
    this.members = const [],
    this.busyId,
    this.notice,
    this.noticeSeq = 0,
    this.failure,
  });

  final LoadStatus status;
  final List<TeamMember> members;

  /// The member an action is running on (its row is inert meanwhile).
  final String? busyId;
  final TeamNotice? notice;

  /// Bumped per notice so the same outcome twice still reaches the listener.
  final int noticeSeq;
  final Failure? failure;

  TeamState copyWith({
    LoadStatus? status,
    List<TeamMember>? members,
    String? busyId,
    bool clearBusy = false,
    TeamNotice? notice,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      TeamState(
        status: status ?? this.status,
        members: members ?? this.members,
        busyId: clearBusy ? null : (busyId ?? this.busyId),
        notice: notice ?? this.notice,
        noticeSeq: notice == null ? noticeSeq : noticeSeq + 1,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [status, members, busyId, notice, noticeSeq, failure];
}

class TeamCubit extends Cubit<TeamState> {
  TeamCubit(this._uc) : super(const TeamState());

  final TeamUseCases _uc;
  bool _loading = false;
  bool _acting = false;

  Future<void> load() async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      if (state.members.isEmpty) {
        emit(const TeamState());
      }
      final result = await _uc.list();
      if (isClosed) {
        return;
      }
      result.fold(
        (f) => emit(state.copyWith(status: LoadStatus.failure, failure: f)),
        (m) => emit(TeamState(status: LoadStatus.loaded, members: m)),
      );
    } finally {
      _loading = false;
    }
  }

  /// Runs one action at a time; the owner row is never touched.
  Future<void> _act(String? id, Future<void> Function() body) async {
    if (_acting) {
      return;
    }
    if (id != null && state.members.any((m) => m.id == id && m.isOwner)) {
      return;
    }
    _acting = true;
    emit(state.copyWith(busyId: id, clearFailure: true));
    try {
      await body();
    } finally {
      _acting = false;
      if (!isClosed) {
        emit(state.copyWith(clearBusy: true));
      }
    }
  }

  void _replace(TeamMember m) {
    emit(state.copyWith(members: [for (final x in state.members) x.id == m.id ? m : x]));
  }

  Future<void> invite(InviteDraft draft) => _act(null, () async {
        final r = await _uc.invite(draft);
        if (isClosed) {
          return;
        }
        r.fold(
          (f) => emit(state.copyWith(notice: TeamNotice.failed, failure: f)),
          (m) => emit(state.copyWith(members: [...state.members, m], notice: TeamNotice.invited)),
        );
      });

  Future<void> changeRole(String id, TeamRole role) => _act(id, () async {
        final r = await _uc.changeRole(id, role);
        if (isClosed) {
          return;
        }
        r.fold(
          (f) => emit(state.copyWith(notice: TeamNotice.failed, failure: f)),
          (m) {
            _replace(m);
            emit(state.copyWith(notice: TeamNotice.roleChanged));
          },
        );
      });

  Future<void> setActive(String id, {required bool active}) => _act(id, () async {
        final r = await _uc.setActive(id, active: active);
        if (isClosed) {
          return;
        }
        r.fold(
          (f) => emit(state.copyWith(notice: TeamNotice.failed, failure: f)),
          (m) {
            _replace(m);
            emit(state.copyWith(notice: active ? TeamNotice.reactivated : TeamNotice.disabled));
          },
        );
      });

  Future<void> resendInvite(String id) => _act(id, () async {
        final r = await _uc.resendInvite(id);
        if (isClosed) {
          return;
        }
        r.fold(
          (f) => emit(state.copyWith(notice: TeamNotice.failed, failure: f)),
          (_) => emit(state.copyWith(notice: TeamNotice.inviteResent)),
        );
      });

  Future<void> cancelInvite(String id) => _act(id, () async {
        final r = await _uc.cancelInvite(id);
        if (isClosed) {
          return;
        }
        r.fold(
          (f) => emit(state.copyWith(notice: TeamNotice.failed, failure: f)),
          (_) => emit(state.copyWith(
              members: [for (final m in state.members) if (m.id != id) m], notice: TeamNotice.inviteCancelled)),
        );
      });
}
