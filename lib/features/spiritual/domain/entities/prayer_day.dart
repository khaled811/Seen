import 'package:equatable/equatable.dart';

import 'prayer_id.dart';

/// The seven timed moments of one calendar day, as absolute instants in the
/// device's time zone. [lastThird] is the start of the last third of the night
/// (the recommended time for qiyam).
class PrayerDay extends Equatable {
  const PrayerDay({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.midnight,
    required this.lastThird,
  });

  /// Midnight (00:00) of the calendar day this is for.
  final DateTime date;
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime midnight;
  final DateTime lastThird;

  DateTime timeOf(PrayerId id) => switch (id) {
        PrayerId.fajr => fajr,
        PrayerId.sunrise => sunrise,
        PrayerId.dhuhr => dhuhr,
        PrayerId.asr => asr,
        PrayerId.maghrib => maghrib,
        PrayerId.isha => isha,
        PrayerId.midnight => midnight,
      };

  /// All seven moments, chronological.
  List<(PrayerId, DateTime)> get entries => [
        for (final id in PrayerId.values) (id, timeOf(id)),
      ];

  /// The first moment strictly after [now], or null when the whole day
  /// (including midnight) is behind us.
  (PrayerId, DateTime)? next(DateTime now) {
    for (final e in entries) {
      if (e.$2.isAfter(now)) return e;
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [date, fajr, sunrise, dhuhr, asr, maghrib, isha, midnight, lastThird];
}
