import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/dua_audio_player.dart';
import 'dua_audio_cubit.dart';

class DuaPlayerState extends Equatable {
  const DuaPlayerState({
    this.activeId,
    this.status = DuaAudioStatus.idle,
    this.position = Duration.zero,
  });

  /// The dua whose clip is loading, playing, or failed to start.
  final String? activeId;
  final DuaAudioStatus status;
  final Duration position;

  bool isActive(String id) =>
      activeId == id &&
      (status == DuaAudioStatus.loading || status == DuaAudioStatus.playing);

  @override
  List<Object?> get props => [activeId, status, position];
}

/// Audio for the dua list: one clip at a time, with progress.
///
/// Lifecycle: owns two subscriptions to the shared player (cancelled in
/// [close]) and stops playback when closed, so audio never outlives the
/// screen.
class DuaPlayerCubit extends Cubit<DuaPlayerState> {
  DuaPlayerCubit(this._player) : super(const DuaPlayerState()) {
    _states = _player.states.listen(_onPlayback);
    _positions = _player.positions.listen(_onPosition);
  }

  final DuaAudioPlayer _player;
  late final StreamSubscription<DuaPlayback> _states;
  late final StreamSubscription<Duration> _positions;

  void _onPlayback(DuaPlayback p) {
    if (isClosed || state.activeId == null) return;
    switch (p) {
      case DuaPlayback.loading:
        emit(DuaPlayerState(activeId: state.activeId, status: DuaAudioStatus.loading));
      case DuaPlayback.playing:
        emit(DuaPlayerState(
          activeId: state.activeId,
          status: DuaAudioStatus.playing,
          position: state.position,
        ));
      case DuaPlayback.idle:
        // Starting a clip reports a stale idle first; only an idle after the
        // clip began (or failed) means it ended.
        if (state.status == DuaAudioStatus.loading ||
            state.status == DuaAudioStatus.error) {
          return;
        }
        emit(const DuaPlayerState());
    }
  }

  void _onPosition(Duration d) {
    if (isClosed || state.status != DuaAudioStatus.playing) return;
    emit(DuaPlayerState(
      activeId: state.activeId,
      status: DuaAudioStatus.playing,
      position: d,
    ));
  }

  /// Plays [asset] for [id], or stops it when it is already playing.
  Future<void> toggle(String id, String? asset) async {
    if (state.isActive(id)) {
      await stop();
      return;
    }
    if (asset == null) {
      emit(DuaPlayerState(activeId: id, status: DuaAudioStatus.error));
      return;
    }
    emit(DuaPlayerState(activeId: id, status: DuaAudioStatus.loading));
    try {
      await _player.play(asset);
    } catch (_) {
      if (!isClosed) {
        emit(DuaPlayerState(activeId: id, status: DuaAudioStatus.error));
      }
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } finally {
      if (!isClosed) emit(const DuaPlayerState());
    }
  }

  @override
  Future<void> close() async {
    try {
      await _player.stop();
    } catch (_) {
      // Nothing left to clean up if the player is already gone.
    }
    await _states.cancel();
    await _positions.cancel();
    return super.close();
  }
}
