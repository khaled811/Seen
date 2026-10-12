import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_id.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_location.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_preferences.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reminder.dart';
import 'package:seen_booking/features/spiritual/domain/services/notification_scheduler.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/prayer_usecases.dart';
import 'package:seen_booking/features/spiritual/domain/utils/reminder_planner.dart';

import '../support/prayer_fakes.dart';

void main() {
  final location = SaudiCities.makkah.toLocation();
  final calc = FixedPrayerCalculator();
  final planner = ReminderPlanner(calc);
  // 03:00 on the anchor day: every moment of the day is still ahead.
  final dawn = DateTime(2026, 10, 3, 3);

  List<Reminder> plan({
    PrayerPreferences prefs = const PrayerPreferences(),
    DateTime? now,
    int days = 7,
  }) =>
      planner.plan(
        location: location,
        prefs: prefs,
        now: now ?? dawn,
        horizonDays: days,
      );

  group('which moments remind', () {
    test('defaults: the five prayers, not sunrise or midnight', () {
      final r = plan(days: 1);
      expect(r.map((e) => e.prayer), [
        PrayerId.fajr,
        PrayerId.dhuhr,
        PrayerId.asr,
        PrayerId.maghrib,
        PrayerId.isha,
      ]);
    });

    test('a week of defaults is 35 reminders', () {
      expect(plan(), hasLength(35));
    });

    test('opting sunrise and midnight in adds them', () {
      final prefs = const PrayerPreferences()
          .withMode(PrayerId.sunrise, AlertMode.sound)
          .withMode(PrayerId.midnight, AlertMode.vibrate);
      final r = plan(prefs: prefs, days: 1);
      expect(r, hasLength(7));
      expect(r.map((e) => e.prayer), PrayerId.values);
    });

    test('a silenced prayer is skipped', () {
      final prefs =
          const PrayerPreferences().withMode(PrayerId.asr, AlertMode.silent);
      expect(
        plan(prefs: prefs, days: 1).map((e) => e.prayer),
        isNot(contains(PrayerId.asr)),
      );
    });

    test('everything silent plans nothing', () {
      final prefs = PrayerPreferences(
        alertModes: {for (final id in PrayerId.values) id: AlertMode.silent},
      );
      expect(plan(prefs: prefs), isEmpty);
    });

    test('the alert mode is carried onto the reminder', () {
      final prefs =
          const PrayerPreferences().withMode(PrayerId.isha, AlertMode.vibrate);
      final isha = plan(prefs: prefs, days: 1)
          .firstWhere((e) => e.prayer == PrayerId.isha);
      expect(isha.mode, AlertMode.vibrate);
    });
  });

  group('time handling', () {
    test('moments already past are not scheduled', () {
      // 13:00: fajr and dhuhr (12:15) are behind us.
      final r = plan(now: DateTime(2026, 10, 3, 13), days: 1);
      expect(r.map((e) => e.prayer), [
        PrayerId.asr,
        PrayerId.maghrib,
        PrayerId.isha,
      ]);
    });

    test('the plan is sorted by time and every reminder is in the future', () {
      final now = DateTime(2026, 10, 3, 13);
      final r = plan(now: now);
      for (var i = 0; i < r.length; i++) {
        expect(r[i].time.isAfter(now), isTrue);
        if (i > 0) expect(!r[i].time.isBefore(r[i - 1].time), isTrue);
      }
    });

    test('later days are included (tomorrow\'s fajr)', () {
      final r = plan(now: DateTime(2026, 10, 3, 23), days: 2);
      expect(r.first.prayer, PrayerId.fajr);
      expect(r.first.time.day, 4);
    });

    test('the horizon is respected', () {
      final r = plan(days: 3);
      expect(r.last.time.day, 5);
    });
  });

  group('pre-alerts', () {
    const prefs = PrayerPreferences(preAlertMinutes: 15);

    test('add one earlier reminder per prayer, never for sunrise/midnight', () {
      final withSun = prefs
          .withMode(PrayerId.sunrise, AlertMode.sound)
          .withMode(PrayerId.midnight, AlertMode.sound);
      final r = plan(prefs: withSun, days: 1);
      final pre = r.where((e) => e.isPreAlert).toList();
      expect(pre, hasLength(5));
      expect(pre.every((e) => e.prayer.isPrayer), isTrue);
      expect(r, hasLength(7 + 5));
    });

    test('fire exactly N minutes before the prayer', () {
      final r = plan(prefs: prefs, days: 1);
      final dhuhr = r.firstWhere((e) => e.prayer == PrayerId.dhuhr && !e.isPreAlert);
      final pre = r.firstWhere((e) => e.prayer == PrayerId.dhuhr && e.isPreAlert);
      expect(dhuhr.time.difference(pre.time), const Duration(minutes: 15));
      expect(pre.title, 'بعد ١٥ دقيقة: صلاة الظهر');
    });

    test('a pre-alert already in the past is dropped but the prayer stays', () {
      // 12:10: dhuhr (12:15) is 5 minutes away, its 15-minute notice is gone.
      final r = plan(prefs: prefs, now: DateTime(2026, 10, 3, 12, 10), days: 1);
      final dhuhr = r.where((e) => e.prayer == PrayerId.dhuhr).toList();
      expect(dhuhr, hasLength(1));
      expect(dhuhr.single.isPreAlert, isFalse);
    });
  });

  group('limits and identity', () {
    test('never more than 60 pending reminders (iOS allows 64)', () {
      final all = const PrayerPreferences(preAlertMinutes: 5)
          .withMode(PrayerId.sunrise, AlertMode.sound)
          .withMode(PrayerId.midnight, AlertMode.sound);
      final r = plan(prefs: all, days: 14);
      expect(r, hasLength(ReminderPlanner.maxPending));
    });

    test('the cap keeps the earliest reminders', () {
      final all = const PrayerPreferences(preAlertMinutes: 5)
          .withMode(PrayerId.sunrise, AlertMode.sound)
          .withMode(PrayerId.midnight, AlertMode.sound);
      final capped = plan(prefs: all, days: 14);
      final uncapped = ReminderPlanner(calc)
          .plan(location: location, prefs: all, now: dawn, horizonDays: 14)
        ..sort((a, b) => a.time.compareTo(b.time));
      expect(capped.map((e) => e.id), uncapped.take(60).map((e) => e.id));
    });

    test('ids are unique', () {
      final all = const PrayerPreferences(preAlertMinutes: 10)
          .withMode(PrayerId.sunrise, AlertMode.sound);
      final ids = plan(prefs: all).map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ids are stable: the same inputs give the same ids', () {
      expect(plan().map((e) => e.id).toList(), plan().map((e) => e.id).toList());
    });

    test('ids stay small enough for a 32-bit notification id', () {
      for (final e in plan(days: 365)) {
        expect(e.id, lessThan(1 << 31));
      }
    });
  });

  group('text', () {
    test('a prayer reminder names the prayer, time and place', () {
      final fajr = plan(days: 1).first;
      expect(fajr.title, 'حان الآن موعد صلاة الفجر');
      expect(fajr.body, contains('مكة المكرمة'));
      expect(fajr.body, contains('ص'));
    });

    test('midnight mentions the last third of the night', () {
      final prefs =
          const PrayerPreferences().withMode(PrayerId.midnight, AlertMode.sound);
      final mid = plan(prefs: prefs, days: 1)
          .firstWhere((e) => e.prayer == PrayerId.midnight)
          ;
      expect(mid.title, 'تذكير: منتصف الليل');
      expect(mid.body, contains('الثلث الأخير'));
    });

    test('digits are Arabic-Indic', () {
      for (final e in plan(days: 1)) {
        expect(RegExp('[0-9]').hasMatch(e.body), isFalse, reason: e.body);
      }
    });
  });

  group('SyncRemindersUseCase', () {
    late FakeScheduler scheduler;
    late SyncRemindersUseCase sync;

    setUp(() {
      scheduler = FakeScheduler();
      sync = SyncRemindersUseCase(scheduler, planner);
    });

    Future<SyncResult> run() async => (await sync(
          location: location,
          prefs: const PrayerPreferences(),
          now: dawn,
        ))
            .getOrElse((f) => throw StateError('$f'));

    test('with permission it replaces the whole schedule', () async {
      final r = await run();
      expect(r.outcome, SyncOutcome.scheduled);
      expect(r.count, 35);
      expect(scheduler.scheduled, hasLength(35));
      expect(scheduler.replaceCalls, 1);
    });

    test('syncing twice replaces, never accumulates', () async {
      await run();
      await run();
      expect(scheduler.scheduled, hasLength(35));
      expect(scheduler.replaceCalls, 2);
    });

    test('not asked yet: nothing is scheduled and no prompt is shown', () async {
      scheduler.current = NotificationPermission.notDetermined;
      final r = await run();
      expect(r.outcome, SyncOutcome.permissionUnknown);
      expect(scheduler.replaceCalls, 0);
      expect(scheduler.requests, 0);
    });

    test('denied: pending reminders are cancelled', () async {
      await run();
      scheduler.current = NotificationPermission.denied;
      final r = await run();
      expect(r.outcome, SyncOutcome.permissionDenied);
      expect(scheduler.cancelCalls, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    test('everything silent is reported as nothing to schedule', () async {
      final r = (await sync(
        location: location,
        prefs: PrayerPreferences(
          alertModes: {for (final id in PrayerId.values) id: AlertMode.silent},
        ),
        now: dawn,
      ))
          .getOrElse((f) => throw StateError('$f'));
      expect(r.outcome, SyncOutcome.nothingToSchedule);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a plugin failure is returned as a Failure, not thrown', () async {
      scheduler.throwOnReplace = true;
      final r = await sync(location: location, prefs: const PrayerPreferences(), now: dawn);
      expect(r.swap().getOrElse((_) => throw 'x'), isA<CacheFailure>());
    });
  });
}
