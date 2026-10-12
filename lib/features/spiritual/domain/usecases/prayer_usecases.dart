import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../core/time_format.dart';
import '../entities/hijri_date.dart';
import '../entities/prayer_day.dart';
import '../entities/prayer_location.dart';
import '../entities/prayer_preferences.dart';
import '../repositories/prayer_preferences_repository.dart';
import '../services/hijri_converter.dart';
import '../services/notification_scheduler.dart';
import '../services/prayer_calculator.dart';
import '../utils/reminder_planner.dart';

/// Times for one calendar day.
class GetPrayerDayUseCase {
  const GetPrayerDayUseCase(this._calculator);

  final PrayerCalculator _calculator;

  PrayerDay call({
    required PrayerLocation location,
    required PrayerPreferences prefs,
    required DateTime date,
  }) =>
      _calculator.calculate(
        location: location,
        date: dateOnly(date),
        method: prefs.method,
        madhab: prefs.madhab,
      );
}

/// One row of the month table.
class MonthDay extends Equatable {
  const MonthDay({required this.hijriDay, required this.day});

  final int hijriDay;
  final PrayerDay day;

  DateTime get date => day.date;

  @override
  List<Object?> get props => [hijriDay, day];
}

/// A full Hijri month with the times of every day.
class HijriMonth extends Equatable {
  const HijriMonth({required this.year, required this.month, required this.days});

  final int year;
  final int month;
  final List<MonthDay> days;

  String get monthName => hijriMonthNames[month - 1];

  @override
  List<Object?> get props => [year, month, days];
}

class GetHijriMonthUseCase {
  const GetHijriMonthUseCase(this._calculator, this._hijri);

  final PrayerCalculator _calculator;
  final HijriConverter _hijri;

  /// The Hijri month containing [anyDayOfMonth].
  HijriMonth call({
    required PrayerLocation location,
    required PrayerPreferences prefs,
    required DateTime anyDayOfMonth,
  }) {
    final h = _hijri.fromGregorian(anyDayOfMonth);
    final count = _hijri.daysInMonth(h.year, h.month);
    final days = [
      for (var d = 1; d <= count; d++)
        MonthDay(
          hijriDay: d,
          day: _calculator.calculate(
            location: location,
            date: _hijri.toGregorian(h.year, h.month, d),
            method: prefs.method,
            madhab: prefs.madhab,
          ),
        ),
    ];
    return HijriMonth(year: h.year, month: h.month, days: days);
  }
}

class GetPreferencesUseCase {
  const GetPreferencesUseCase(this._repository);

  final PrayerPreferencesRepository _repository;

  Future<PrayerPreferences> call() => _repository.load();
}

class SavePreferencesUseCase {
  const SavePreferencesUseCase(this._repository);

  final PrayerPreferencesRepository _repository;

  Future<Either<Failure, PrayerPreferences>> call(PrayerPreferences prefs) =>
      _repository.save(prefs);
}

enum SyncOutcome {
  /// Reminders are scheduled.
  scheduled,

  /// Permission is granted but the user silenced everything.
  nothingToSchedule,

  /// The user refused notifications; nothing is scheduled.
  permissionDenied,

  /// Not asked yet; nothing is scheduled until the user decides.
  permissionUnknown,
}

class SyncResult extends Equatable {
  const SyncResult(this.outcome, {this.count = 0});

  final SyncOutcome outcome;
  final int count;

  @override
  List<Object?> get props => [outcome, count];
}

/// Plans the next week of reminders and hands them to the scheduler. Safe to
/// call as often as needed (every app open, every settings change): the
/// scheduler replaces the previous set.
class SyncRemindersUseCase {
  const SyncRemindersUseCase(this._scheduler, this._planner);

  final NotificationScheduler _scheduler;
  final ReminderPlanner _planner;

  Future<Either<Failure, SyncResult>> call({
    required PrayerLocation location,
    required PrayerPreferences prefs,
    required DateTime now,
  }) async {
    try {
      final permission = await _scheduler.permission();
      if (permission == NotificationPermission.notDetermined) {
        return const Right(SyncResult(SyncOutcome.permissionUnknown));
      }
      if (permission == NotificationPermission.denied) {
        await _scheduler.cancelAll();
        return const Right(SyncResult(SyncOutcome.permissionDenied));
      }
      final plan = _planner.plan(location: location, prefs: prefs, now: now);
      await _scheduler.replaceAll(plan);
      return Right(SyncResult(
        plan.isEmpty ? SyncOutcome.nothingToSchedule : SyncOutcome.scheduled,
        count: plan.length,
      ));
    } catch (e) {
      return Left(CacheFailure('Could not schedule prayer reminders: $e'));
    }
  }
}

/// Asks for notification permission (shows the system dialog if undecided).
class RequestNotificationPermissionUseCase {
  const RequestNotificationPermissionUseCase(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<NotificationPermission> call() => _scheduler.requestPermission();
}

class CheckNotificationPermissionUseCase {
  const CheckNotificationPermissionUseCase(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<NotificationPermission> call() => _scheduler.permission();
}
