import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../domain/services/dua_audio_player.dart';

/// [DuaAudioPlayer] over a single shared `just_audio` player, so only one dua
/// plays at a time app-wide. The native player is created on first use.
class JustAudioDuaPlayer implements DuaAudioPlayer {
  JustAudioDuaPlayer._();

  static final shared = JustAudioDuaPlayer._();

  AudioPlayer? _player;
  final _states = StreamController<DuaPlayback>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  StreamSubscription<PlayerState>? _sub;
  StreamSubscription<Duration>? _positionSub;

  @override
  Stream<DuaPlayback> get states => _states.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

  AudioPlayer _ensure() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _positionSub = player.positionStream.listen(_positions.add);
    _sub = player.playerStateStream.listen((s) {
      _states.add(switch (s.processingState) {
        ProcessingState.loading || ProcessingState.buffering =>
          DuaPlayback.loading,
        ProcessingState.ready =>
          s.playing ? DuaPlayback.playing : DuaPlayback.idle,
        ProcessingState.completed => DuaPlayback.idle,
        ProcessingState.idle => DuaPlayback.idle,
      });
      if (s.processingState == ProcessingState.completed) {
        // Rewind so the next play() starts from the beginning.
        unawaited(player.pause());
        unawaited(player.seek(Duration.zero));
      }
    });
    return _player = player;
  }

  @override
  Future<void> play(String asset) async {
    final player = _ensure();
    await player.setAsset(asset);
    // play() completes when the clip ends; do not block the caller on it.
    unawaited(player.play());
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    await player.stop();
  }

  /// Releases the native player (app shutdown / tests).
  Future<void> dispose() async {
    await _sub?.cancel();
    await _positionSub?.cancel();
    await _player?.dispose();
    _player = null;
    _sub = null;
    _positionSub = null;
  }
}
