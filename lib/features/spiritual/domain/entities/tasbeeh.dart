import 'package:equatable/equatable.dart';

/// One phrase of the tasbeeh list (`assets/data/tasbeeh_adhkar.json`).
class TasbeehDhikr extends Equatable {
  const TasbeehDhikr({required this.id, required this.label});

  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

/// How many counts make a round. [open] never completes.
enum TasbeehTarget {
  thirtyThree(33),
  hundred(100),
  open(0);

  const TasbeehTarget(this.value);

  /// Counts per round; 0 for [open].
  final int value;

  bool get isOpen => this == open;

  static TasbeehTarget? fromValue(int? value) {
    for (final t in values) {
      if (t.value == value) return t;
    }
    return null;
  }
}

/// A dhikr's tally for one calendar day.
class DhikrDay extends Equatable {
  const DhikrDay({this.total = 0, this.rounds = 0});

  final int total;
  final int rounds;

  @override
  List<Object?> get props => [total, rounds];
}

/// Everything the tasbeeh remembers; persisted on every change so an
/// unexpected close never loses progress.
class TasbeehProgress extends Equatable {
  const TasbeehProgress({
    required this.dhikrId,
    this.target = TasbeehTarget.thirtyThree,
    this.count = 0,
    this.complete = false,
    required this.day,
    this.daily = const {},
  });

  final String dhikrId;
  final TasbeehTarget target;

  /// Counts in the current round (or since the last reset, when open).
  final int count;

  /// The target was reached and the next tap starts a new round.
  final bool complete;

  /// Local calendar day ("yyyy-MM-dd") the [daily] tallies belong to.
  final String day;

  /// Today's tally per dhikr id.
  final Map<String, DhikrDay> daily;

  DhikrDay get today => daily[dhikrId] ?? const DhikrDay();

  TasbeehProgress copyWith({
    String? dhikrId,
    TasbeehTarget? target,
    int? count,
    bool? complete,
    String? day,
    Map<String, DhikrDay>? daily,
  }) =>
      TasbeehProgress(
        dhikrId: dhikrId ?? this.dhikrId,
        target: target ?? this.target,
        count: count ?? this.count,
        complete: complete ?? this.complete,
        day: day ?? this.day,
        daily: daily ?? this.daily,
      );

  @override
  List<Object?> get props => [dhikrId, target, count, complete, day, daily];
}
