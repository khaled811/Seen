import '../../domain/entities/rite_mode.dart';
import '../../domain/entities/tawaf_session.dart';

/// JSON shape of a persisted [TawafSession]. Strict on read: anything that
/// does not describe a valid session throws [FormatException].
class TawafSessionDto {
  const TawafSessionDto({
    required this.mode,
    required this.currentLap,
    required this.done,
    required this.startedAtMs,
    required this.lapTimestampsMs,
  });

  factory TawafSessionDto.fromEntity(TawafSession s) => TawafSessionDto(
        mode: s.mode.name,
        currentLap: s.currentLap,
        done: s.done,
        startedAtMs: s.startedAt.millisecondsSinceEpoch,
        lapTimestampsMs:
            s.lapTimestamps.map((t) => t.millisecondsSinceEpoch).toList(),
      );

  factory TawafSessionDto.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('session is not an object');
    }
    final mode = json['mode'];
    final lap = json['currentLap'];
    final done = json['done'];
    final started = json['startedAt'];
    final laps = json['lapTimestamps'];
    if (mode is! String ||
        lap is! int ||
        done is! bool ||
        started is! int ||
        laps is! List ||
        laps.any((e) => e is! int)) {
      throw const FormatException('session has malformed fields');
    }
    if (!RiteMode.values.any((m) => m.name == mode)) {
      throw FormatException('unknown mode "$mode"');
    }
    if (lap < 1 || lap > TawafSession.totalLaps) {
      throw FormatException('lap $lap out of range');
    }
    return TawafSessionDto(
      mode: mode,
      currentLap: lap,
      done: done,
      startedAtMs: started,
      lapTimestampsMs: laps.cast<int>(),
    );
  }

  final String mode;
  final int currentLap;
  final bool done;
  final int startedAtMs;
  final List<int> lapTimestampsMs;

  Map<String, Object?> toJson() => {
        'mode': mode,
        'currentLap': currentLap,
        'done': done,
        'startedAt': startedAtMs,
        'lapTimestamps': lapTimestampsMs,
      };

  TawafSession toEntity() => TawafSession(
        mode: RiteMode.values.firstWhere((m) => m.name == mode),
        currentLap: currentLap,
        done: done,
        startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
        lapTimestamps: [
          for (final ms in lapTimestampsMs)
            DateTime.fromMillisecondsSinceEpoch(ms),
        ],
      );
}
