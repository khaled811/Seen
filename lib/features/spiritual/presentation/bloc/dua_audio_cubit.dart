import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/dua_audio_player.dart';

enum DuaAudioStatus { idle, loading, playing, error }

class DuaAudioState extends Equatable {
  const DuaAudioState(this.status);

  final DuaAudioStatus status;

  bool get isActive =>
      status == DuaAudioStatus.loading || status == DuaAudioStatus.playing;

  @override
  List<Object?> get props => [status];
}

/// Play/stop control for one dua clip.
///
/// Lifecycle: owns the subscription to the player's state stream (cancelled
/// in [close]) and stops playback when closed, so audio never outlives the
/// screen. The underlying player is shared app-wide.
class DuaAudioCubit extends Cubit<DuaAudioState> {
  DuaAudioCubit(this._player) : super(const DuaAudioState(DuaAudioStatus.idle)) {
    _sub = _player.states.listen(_onPlayback);
  }

  final DuaAudioPlayer _player;
  late final StreamSubscription<DuaPlayback> _sub;

  void _onPlayback(DuaPlayback p) {
    if (isClosed) return;
    // Keep `error` visible until the next user action.
    if (state.status == DuaAudioStatus.error && p == DuaPlayback.idle) return;
    emit(DuaAudioState(switch (p) {
      DuaPlayback.idle => DuaAudioStatus.idle,
      DuaPlayback.loading => DuaAudioStatus.loading,
      DuaPlayback.playing => DuaAudioStatus.playing,
    }));
  }

  Future<void> toggle(String? asset) async {
    if (state.isActive) {
      await stop();
      return;
    }
    if (asset == null) {
      emit(const DuaAudioState(DuaAudioStatus.error));
      return;
    }
    emit(const DuaAudioState(DuaAudioStatus.loading));
    try {
      await _player.play(asset);
    } catch (_) {
      if (!isClosed) emit(const DuaAudioState(DuaAudioStatus.error));
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } finally {
      if (!isClosed) emit(const DuaAudioState(DuaAudioStatus.idle));
    }
  }

  @override
  Future<void> close() async {
    // Stop the audio first: it must never outlive the screen, even if tearing
    // down the subscription is slow.
    try {
      await _player.stop();
    } catch (_) {
      // Nothing left to clean up if the player is already gone.
    }
    await _sub.cancel();
    return super.close();
  }
}
