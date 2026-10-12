import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/dua.dart';
import '../../domain/entities/dua_filter.dart';
import '../../domain/usecases/dua_library_usecases.dart';
import '../../domain/usecases/get_duas_usecase.dart';
import '../../domain/utils/dua_text.dart';

enum DuasStatus { loading, ready, failure }

/// A one-off message for the screen's snackbar.
enum DuasNotice { none, shareFailed, copyFailed, saveFailed }

class DuasState extends Equatable {
  const DuasState({
    this.status = DuasStatus.loading,
    this.duas = const [],
    this.visible = const [],
    this.favorites = const {},
    this.filter = DuaFilter.all,
    this.query = '',
    this.openId,
    this.copiedId,
    this.notice = DuasNotice.none,
    this.noticeSeq = 0,
  });

  /// Every dua the repository exposes (already gated on `reviewed`).
  final List<Dua> duas;

  /// [duas] narrowed by [filter] and [query], computed once per change so
  /// `build()` never filters.
  final List<Dua> visible;
  final DuasStatus status;
  final Set<String> favorites;
  final DuaFilter filter;
  final String query;

  /// The one expanded card.
  final String? openId;

  /// The card whose copy button shows "تم النسخ".
  final String? copiedId;
  final DuasNotice notice;

  /// Bumped with every notice so the same message can fire twice in a row.
  final int noticeSeq;

  DuasState copyWith({
    DuasStatus? status,
    List<Dua>? duas,
    Set<String>? favorites,
    DuaFilter? filter,
    String? query,
    String? Function()? openId,
    String? Function()? copiedId,
    DuasNotice? notice,
  }) {
    final nextDuas = duas ?? this.duas;
    final nextFavorites = favorites ?? this.favorites;
    final nextFilter = filter ?? this.filter;
    final nextQuery = query ?? this.query;
    final refilter = duas != null ||
        favorites != null ||
        filter != null ||
        query != null;
    return DuasState(
      status: status ?? this.status,
      duas: nextDuas,
      visible: refilter
          ? filterDuas(
              nextDuas,
              filter: nextFilter,
              favorites: nextFavorites,
              query: nextQuery,
            )
          : visible,
      favorites: nextFavorites,
      filter: nextFilter,
      query: nextQuery,
      openId: openId != null ? openId() : this.openId,
      copiedId: copiedId != null ? copiedId() : this.copiedId,
      notice: notice ?? this.notice,
      noticeSeq: notice != null && notice != DuasNotice.none
          ? noticeSeq + 1
          : noticeSeq,
    );
  }

  @override
  List<Object?> get props => [
        status,
        duas,
        visible,
        favorites,
        filter,
        query,
        openId,
        copiedId,
        notice,
        noticeSeq,
      ];
}

/// The dua library: category/search/saved filtering, the open card, the saved
/// list, and the share and copy actions.
///
/// Owns one [Timer] (the 1.6 s "copied" label), cancelled in [close].
class DuasCubit extends Cubit<DuasState> {
  DuasCubit({
    required GetDuasUseCase getDuas,
    required LoadDuaUserDataUseCase loadUserData,
    required ToggleFavoriteDuaUseCase toggleFavorite,
    required SaveDuaFilterUseCase saveFilter,
    required ShareDuaUseCase share,
    required CopyDuaUseCase copy,
    this.copiedFor = const Duration(milliseconds: 1600),
  })  : _getDuas = getDuas,
        _loadUserData = loadUserData,
        _toggleFavorite = toggleFavorite,
        _saveFilter = saveFilter,
        _share = share,
        _copy = copy,
        super(const DuasState());

  final GetDuasUseCase _getDuas;
  final LoadDuaUserDataUseCase _loadUserData;
  final ToggleFavoriteDuaUseCase _toggleFavorite;
  final SaveDuaFilterUseCase _saveFilter;
  final ShareDuaUseCase _share;
  final CopyDuaUseCase _copy;
  final Duration copiedFor;

  Timer? _copiedTimer;

  Future<void> load() async {
    emit(state.copyWith(status: DuasStatus.loading));
    final duas = await _getDuas();
    final user = await _loadUserData();
    if (isClosed) return;
    duas.fold(
      (_) => emit(state.copyWith(status: DuasStatus.failure)),
      (list) {
        // Unreadable user data must not hide the library: start with none.
        final data = user.fold((_) => null, (d) => d);
        emit(state.copyWith(
          status: DuasStatus.ready,
          duas: list,
          favorites: data?.favorites,
          filter: data?.filter,
          openId: () => null,
        ));
      },
    );
  }

  Future<void> selectFilter(DuaFilter filter) async {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter, openId: () => null));
    final saved = await _saveFilter(filter);
    saved.fold((_) => _notify(DuasNotice.saveFailed), (_) {});
  }

  void search(String query) {
    if (query == state.query) return;
    emit(state.copyWith(query: query, openId: () => null));
  }

  /// Opens [id], or closes it when it is already open (one card at a time).
  void toggleOpen(String id) =>
      emit(state.copyWith(openId: () => state.openId == id ? null : id));

  /// Flips the saved state at once and persists; if the write fails the flip
  /// is undone and the user is told.
  Future<void> toggleFavorite(String id) async {
    _flip(id);
    final saved = await _toggleFavorite(id);
    if (isClosed) return;
    saved.fold((_) {
      _flip(id);
      _notify(DuasNotice.saveFailed);
    }, (_) {});
  }

  void _flip(String id) {
    final next = {...state.favorites};
    if (!next.remove(id)) next.add(id);
    emit(state.copyWith(favorites: next));
  }

  Future<void> share(Dua dua) async {
    final ok = await _share(dua);
    if (!ok && !isClosed) _notify(DuasNotice.shareFailed);
  }

  Future<void> copy(Dua dua) async {
    final ok = await _copy(dua);
    if (isClosed) return;
    if (!ok) {
      _notify(DuasNotice.copyFailed);
      return;
    }
    emit(state.copyWith(copiedId: () => dua.id));
    _copiedTimer?.cancel();
    _copiedTimer = Timer(copiedFor, () {
      if (!isClosed) emit(state.copyWith(copiedId: () => null));
    });
  }

  void _notify(DuasNotice notice) => emit(state.copyWith(notice: notice));

  @override
  Future<void> close() {
    _copiedTimer?.cancel();
    return super.close();
  }
}
