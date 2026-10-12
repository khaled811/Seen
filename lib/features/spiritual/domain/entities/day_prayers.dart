import 'package:equatable/equatable.dart';

/// The five daily prayers shown on the dashboard timeline.
enum PrayerSlot { fajr, dhuhr, asr, maghrib, isha }

class PrayerTime extends Equatable {
  const PrayerTime(this.slot, this.time);

  final PrayerSlot slot;
  final DateTime time;

  @override
  List<Object?> get props => [slot, time];
}

/// The upcoming prayer relative to a moment in time.
class NextPrayer extends Equatable {
  const NextPrayer({
    required this.index,
    required this.slot,
    required this.time,
    required this.remainingMinutes,
    required this.isTomorrow,
  });

  /// Position in [DayPrayers.times] (0 = fajr).
  final int index;
  final PrayerSlot slot;
  final DateTime time;

  /// Whole minutes left, rounded up (so "٠٠:٣٥" until the last second of the
  /// 35th minute, never a premature "٠٠:٠٠").
  final int remainingMinutes;

  /// True once every prayer of today has passed and [time] is tomorrow's fajr.
  final bool isTomorrow;

  /// How many timeline entries are already in the past.
  int get pastCount => isTomorrow ? 5 : index;

  @override
  List<Object?> get props => [index, slot, time, remainingMinutes, isTomorrow];
}

/// Today's five prayer times, in chronological order.
class DayPrayers extends Equatable {
  const DayPrayers(this.times, {this.tomorrowFajr});

  final List<PrayerTime> times;

  /// Tomorrow's fajr when known; otherwise today's fajr plus 24 h is used.
  final DateTime? tomorrowFajr;

  /// The first prayer strictly after [now]; tomorrow's fajr (today's time
  /// plus 24 h) once isha has passed. Mock/estimate until the real calculation
  /// arrives in M5.
  NextPrayer next(DateTime now) {
    for (var i = 0; i < times.length; i++) {
      if (times[i].time.isAfter(now)) {
        return _build(i, times[i].time, now, isTomorrow: false);
      }
    }
    final fajr = times.first;
    return _build(
      0,
      tomorrowFajr ?? fajr.time.add(const Duration(days: 1)),
      now,
      isTomorrow: true,
    );
  }

  NextPrayer _build(
    int index,
    DateTime time,
    DateTime now, {
    required bool isTomorrow,
  }) {
    final seconds = time.difference(now).inSeconds;
    return NextPrayer(
      index: index,
      slot: times[index].slot,
      time: time,
      remainingMinutes: (seconds / 60).ceil(),
      isTomorrow: isTomorrow,
    );
  }

  @override
  List<Object?> get props => [times, tomorrowFajr];
}
