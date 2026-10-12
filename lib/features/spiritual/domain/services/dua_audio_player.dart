enum DuaPlayback { idle, loading, playing }

/// App-wide dua audio. Only one clip may play at a time; starting another
/// replaces the current one.
abstract interface class DuaAudioPlayer {
  /// Playback state; returns to [DuaPlayback.idle] when a clip ends or stops.
  Stream<DuaPlayback> get states;

  /// Playback position while a clip plays (about every 200 ms).
  Stream<Duration> get positions;

  /// Starts [asset]. Throws if the asset is missing or cannot be decoded.
  Future<void> play(String asset);

  Future<void> stop();
}
