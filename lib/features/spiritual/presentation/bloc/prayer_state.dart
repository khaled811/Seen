import 'package:equatable/equatable.dart';

import '../../domain/entities/hijri_date.dart';
import '../../domain/entities/prayer_day.dart';
import '../../domain/entities/prayer_id.dart';
import '../../domain/entities/prayer_preferences.dart';
import '../../domain/entities/resolved_location.dart';
import '../../domain/services/notification_scheduler.dart';
import '../../domain/usecases/prayer_usecases.dart';
import 'prayer_event.dart';

sealed class PrayerState extends Equatable {
  const PrayerState();

  @override
  List<Object?> get props => [];
}

class PrayerLoading extends PrayerState {
  const PrayerLoading();
}

class PrayerLoaded extends PrayerState {
  const PrayerLoaded({
    required this.resolved,
    required this.prefs,
    required this.view,
    required this.date,
    required this.day,
    required this.hijri,
    required this.now,
    required this.selected,
    required this.notifications,
    required this.syncOutcome,
    this.month,
    this.saveFailed = false,
    this.saveSeq = 0,
  });

  final ResolvedLocation resolved;
  final PrayerPreferences prefs;
  final PrayerView view;

  /// The day being shown (00:00).
  final DateTime date;
  final PrayerDay day;

  /// Hijri date of [date].
  final HijriDate hijri;

  /// The current time at minute resolution (changes once a minute).
  final DateTime now;

  /// Marker selected on the horizon.
  final PrayerId selected;

  /// The month table; only computed while [view] is month.
  final HijriMonth? month;
  final NotificationPermission notifications;
  final SyncOutcome syncOutcome;

  /// The last preference write failed (UI warns once per [saveSeq]).
  final bool saveFailed;
  final int saveSeq;

  bool get isToday =>
      date.year == now.year && date.month == now.month && date.day == now.day;

  /// Splits past from future: real now for today, end of day for past days,
  /// start of day for future days.
  DateTime get reference {
    if (isToday) return now;
    return date.isBefore(DateTime(now.year, now.month, now.day))
        ? date.add(const Duration(days: 1))
        : date.subtract(const Duration(seconds: 1));
  }

  /// The next moment of today (null on other days or after midnight).
  PrayerId? get nextPrayer => isToday ? day.next(now)?.$1 : null;

  PrayerLoaded copyWith({
    ResolvedLocation? resolved,
    PrayerPreferences? prefs,
    PrayerView? view,
    DateTime? date,
    PrayerDay? day,
    HijriDate? hijri,
    DateTime? now,
    PrayerId? selected,
    HijriMonth? month,
    bool clearMonth = false,
    NotificationPermission? notifications,
    SyncOutcome? syncOutcome,
    bool? saveFailed,
    int? saveSeq,
  }) =>
      PrayerLoaded(
        resolved: resolved ?? this.resolved,
        prefs: prefs ?? this.prefs,
        view: view ?? this.view,
        date: date ?? this.date,
        day: day ?? this.day,
        hijri: hijri ?? this.hijri,
        now: now ?? this.now,
        selected: selected ?? this.selected,
        month: clearMonth ? null : (month ?? this.month),
        notifications: notifications ?? this.notifications,
        syncOutcome: syncOutcome ?? this.syncOutcome,
        saveFailed: saveFailed ?? this.saveFailed,
        saveSeq: saveSeq ?? this.saveSeq,
      );

  @override
  List<Object?> get props => [
        resolved,
        prefs,
        view,
        date,
        day,
        hijri,
        now,
        selected,
        month,
        notifications,
        syncOutcome,
        saveFailed,
        saveSeq,
      ];
}
