import 'package:equatable/equatable.dart';

import 'rite_mode.dart';

/// Persisted state of an active Tawaf / Sa'i counter.
///
/// Immutable; every transition returns a new session. [currentLap] is the lap
/// in progress (1..[totalLaps]); once the last lap is recorded [done] flips to
/// true and [currentLap] stays at [totalLaps].
class TawafSession extends Equatable {
  const TawafSession({
    required this.mode,
    required this.currentLap,
    required this.done,
    required this.startedAt,
    this.lapTimestamps = const [],
  }) : assert(currentLap >= 1 && currentLap <= totalLaps);

  factory TawafSession.start(RiteMode mode, DateTime now) => TawafSession(
        mode: mode,
        currentLap: 1,
        done: false,
        startedAt: now,
      );

  static const totalLaps = 7;

  final RiteMode mode;
  final int currentLap;
  final bool done;
  final DateTime startedAt;
  final List<DateTime> lapTimestamps;

  int get completedLaps => done ? totalLaps : currentLap - 1;
  bool get hasProgress => completedLaps > 0;
  bool get canUndo => completedLaps > 0;
  bool get isLastLap => !done && currentLap == totalLaps;

  /// Records the lap in progress. No-op once [done].
  TawafSession recordLap(DateTime now) {
    if (done) return this;
    final stamps = [...lapTimestamps, now];
    return isLastLap
        ? _copy(done: true, lapTimestamps: stamps)
        : _copy(currentLap: currentLap + 1, lapTimestamps: stamps);
  }

  /// Reverts the most recent recorded lap. No-op with no progress.
  TawafSession undoLap() {
    if (!canUndo) return this;
    final stamps = lapTimestamps.isEmpty
        ? lapTimestamps
        : lapTimestamps.sublist(0, lapTimestamps.length - 1);
    return done
        ? _copy(done: false, lapTimestamps: stamps)
        : _copy(currentLap: currentLap - 1, lapTimestamps: stamps);
  }

  TawafSession _copy({
    int? currentLap,
    bool? done,
    List<DateTime>? lapTimestamps,
  }) =>
      TawafSession(
        mode: mode,
        currentLap: currentLap ?? this.currentLap,
        done: done ?? this.done,
        startedAt: startedAt,
        lapTimestamps: lapTimestamps ?? this.lapTimestamps,
      );

  @override
  List<Object?> get props => [mode, currentLap, done, startedAt, lapTimestamps];
}
