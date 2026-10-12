import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/calc_settings.dart';
import 'package:seen_booking/features/spiritual/domain/entities/location_fix.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_id.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_preferences.dart';
import 'package:seen_booking/features/spiritual/domain/services/notification_scheduler.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/prayer_usecases.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/prayer_bloc.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/prayer_event.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/prayer_state.dart';

import '../support/prayer_fakes.dart';

Future<PrayerBloc> _started(
  PrayerHarness h, {
  Duration tick = const Duration(hours: 1),
}) async {
  final bloc = PrayerBloc(h.module, tickInterval: tick)..add(const PrayerStarted());
  await bloc.stream.firstWhere((s) => s is PrayerLoaded);
  return bloc;
}

PrayerLoaded _s(PrayerBloc b) => b.state as PrayerLoaded;

Future<void> _settle([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('start', () {
    test('loads today with the real location, hijri date and next prayer',
        () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final s = _s(bloc);
      expect(s.resolved.location.name, 'موقعك الحالي');
      expect(s.view, PrayerView.day);
      expect(s.date, DateTime(2026, 10, 3));
      expect(s.isToday, isTrue);
      expect(s.hijri.day, 22);
      expect(s.hijri.monthName, 'ربيع الآخر');
      expect(s.day.dhuhr, DateTime(2026, 10, 3, 12, 15));
      expect(s.nextPrayer, PrayerId.dhuhr);
      expect(s.selected, PrayerId.dhuhr);
      expect(s.now, DateTime(2026, 10, 3, 11, 40));
      await bloc.close();
    });

    test('the first visit asks for location and notifications, once', () async {
      final h = PrayerHarness(permission: NotificationPermission.notDetermined);
      final first = await _started(h);
      expect(h.location.asked, [true], reason: 'asked for location');
      expect(h.scheduler.requests, 1, reason: 'asked for notifications');
      expect(h.prefs.value.locationPrompted, isTrue);
      expect(h.prefs.value.notificationsPrompted, isTrue);
      await first.close();

      final second = await _started(h);
      expect(h.location.asked, [true],
          reason: 'no second prompt; the fresh fix is reused, GPS not queried');
      expect(h.scheduler.requests, 1);
      await second.close();
    });

    test('with every alert silent the notification prompt is skipped', () async {
      final h = PrayerHarness(
        permission: NotificationPermission.notDetermined,
        prefs: PrayerPreferences(
          alertModes: {for (final id in PrayerId.values) id: AlertMode.silent},
        ),
      );
      final bloc = await _started(h);
      expect(h.scheduler.requests, 0);
      await bloc.close();
    });

    test('reminders are scheduled for the week ahead', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      expect(h.scheduler.replaceCalls, 1);
      expect(_s(bloc).syncOutcome, SyncOutcome.scheduled);
      // Fajr (04:58) and sunrise are behind us; dhuhr onwards today + 6 days.
      expect(h.scheduler.scheduled.first.prayer, PrayerId.dhuhr);
      expect(h.scheduler.scheduled.length, 4 + 6 * 5);
      await bloc.close();
    });

    test('a refused notification permission is reported, nothing scheduled',
        () async {
      final h = PrayerHarness(permission: NotificationPermission.notDetermined);
      h.scheduler.onRequest = NotificationPermission.denied;
      final bloc = await _started(h);
      expect(_s(bloc).notifications, NotificationPermission.denied);
      expect(_s(bloc).syncOutcome, SyncOutcome.permissionDenied);
      expect(h.scheduler.scheduled, isEmpty);
      await bloc.close();
    });

    test('location denied: falls back to Makkah and says why', () async {
      final h = PrayerHarness(fix: const LocationDenied());
      final bloc = await _started(h);
      final s = _s(bloc);
      expect(s.resolved.isFallback, isTrue);
      expect(s.resolved.location.name, 'مكة المكرمة');
      expect(s.day.dhuhr, DateTime(2026, 10, 3, 12, 15));
      await bloc.close();
    });
  });

  group('clock', () {
    test('a tick in a new minute moves "now"; the same minute does nothing',
        () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final states = <PrayerState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PrayerTicked());
      await _settle();
      expect(states, isEmpty, reason: 'same minute');

      h.advance(const Duration(minutes: 1));
      bloc.add(const PrayerTicked());
      await _settle();
      expect(_s(bloc).now, DateTime(2026, 10, 3, 11, 41));
      await sub.cancel();
      await bloc.close();
    });

    test('the timer ticks by itself and stops when the bloc closes', () async {
      final h = PrayerHarness();
      final bloc = await _started(h, tick: const Duration(milliseconds: 20));
      h.advance(const Duration(minutes: 5));
      await _settle(80);
      expect(_s(bloc).now, DateTime(2026, 10, 3, 11, 45));

      await bloc.close();
      h.advance(const Duration(minutes: 5));
      await _settle(80);
      expect(_s(bloc).now, DateTime(2026, 10, 3, 11, 45), reason: 'timer cancelled');
    });
  });

  group('navigation', () {
    test('next and previous day', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerDateShifted(1));
      await _settle();
      var s = _s(bloc);
      expect(s.date, DateTime(2026, 10, 4));
      expect(s.isToday, isFalse);
      expect(s.nextPrayer, isNull, reason: 'no "next" on another day');
      expect(s.hijri.day, 23);
      expect(s.selected, PrayerId.dhuhr);

      bloc.add(const PrayerDateShifted(-2));
      await _settle();
      s = _s(bloc);
      expect(s.date, DateTime(2026, 10, 2));
      expect(s.hijri.day, 21);
      await bloc.close();
    });

    test('times change from day to day', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final today = _s(bloc).day;
      bloc.add(const PrayerDateShifted(10));
      await _settle();
      expect(_s(bloc).day, isNot(today));
      expect(_s(bloc).day.date, DateTime(2026, 10, 13));
      await bloc.close();
    });

    test('going back to today restores the "next prayer"', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerDateShifted(1));
      bloc.add(const PrayerDateShifted(-1));
      await _settle();
      expect(_s(bloc).isToday, isTrue);
      expect(_s(bloc).nextPrayer, PrayerId.dhuhr);
      expect(_s(bloc).selected, PrayerId.dhuhr);
      await bloc.close();
    });

    test('the reference splits past/future correctly on other days', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerDateShifted(-1));
      await _settle();
      expect(_s(bloc).reference.isAfter(_s(bloc).day.midnight), isTrue,
          reason: 'a past day is entirely behind us');
      bloc.add(const PrayerDateShifted(2));
      await _settle();
      expect(_s(bloc).reference.isBefore(_s(bloc).day.fajr), isTrue,
          reason: 'a future day is entirely ahead');
      await bloc.close();
    });

    test('marker selection', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerMarkerSelected(PrayerId.isha));
      await _settle();
      expect(_s(bloc).selected, PrayerId.isha);
      await bloc.close();
    });
  });

  group('month view', () {
    test('switching shows the whole Hijri month containing the day', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerViewChanged(PrayerView.month));
      await _settle();
      final s = _s(bloc);
      final month = s.month!;
      expect(s.view, PrayerView.month);
      expect(month.year, 1448);
      expect(month.month, 4);
      expect(month.monthName, 'ربيع الآخر');
      expect(month.days.length, anyOf(29, 30));
      expect(month.days.first.hijriDay, 1);
      expect(month.days.last.hijriDay, month.days.length);
      expect(month.days.any((d) => d.date == DateTime(2026, 10, 3)), isTrue);
      await bloc.close();
    });

    test('every day of the month has its own times', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerViewChanged(PrayerView.month));
      await _settle();
      final days = _s(bloc).month!.days;
      for (var i = 1; i < days.length; i++) {
        expect(days[i].date.isAfter(days[i - 1].date), isTrue);
      }
      expect(days.first.day.fajr, isNot(days.last.day.fajr));
      await bloc.close();
    });

    test('next / previous move by a Hijri month, keeping the day number',
        () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerViewChanged(PrayerView.month));
      await _settle();
      bloc.add(const PrayerDateShifted(1));
      await _settle();
      expect(_s(bloc).month!.month, 5);
      expect(_s(bloc).hijri.day, 22);
      bloc.add(const PrayerDateShifted(-2));
      await _settle();
      expect(_s(bloc).month!.month, 3);
      await bloc.close();
    });

    test('rolling past the end of the year changes the Hijri year', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerViewChanged(PrayerView.month));
      for (var i = 0; i < 9; i++) {
        bloc.add(const PrayerDateShifted(1));
      }
      await _settle(80);
      expect(_s(bloc).month!.year, 1449);
      expect(_s(bloc).month!.month, 1);
      await bloc.close();
    });

    test('switching back to the day view drops the month table', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerViewChanged(PrayerView.month));
      await _settle();
      bloc.add(const PrayerViewChanged(PrayerView.day));
      await _settle();
      expect(_s(bloc).month, isNull);
      expect(_s(bloc).view, PrayerView.day);
      await bloc.close();
    });
  });

  group('alert modes', () {
    test('cycle sound -> vibrate -> silent -> sound and persist each step',
        () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final seen = <AlertMode>[];
      for (var i = 0; i < 3; i++) {
        bloc.add(const PrayerAlertCycled(PrayerId.asr));
        await _settle();
        seen.add(_s(bloc).prefs.modeOf(PrayerId.asr));
        expect(h.prefs.value.modeOf(PrayerId.asr), seen.last, reason: 'persisted');
      }
      expect(seen, [AlertMode.vibrate, AlertMode.silent, AlertMode.sound]);
      await bloc.close();
    });

    test('each change re-plans the reminders', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final before = h.scheduler.replaceCalls;
      bloc.add(const PrayerAlertCycled(PrayerId.asr)); // -> vibrate
      await _settle();
      expect(h.scheduler.replaceCalls, before + 1);
      expect(
        h.scheduler.scheduled
            .where((r) => r.prayer == PrayerId.asr)
            .every((r) => r.mode == AlertMode.vibrate),
        isTrue,
      );
      bloc.add(const PrayerAlertCycled(PrayerId.asr)); // -> silent
      await _settle();
      expect(h.scheduler.scheduled.any((r) => r.prayer == PrayerId.asr), isFalse);
      await bloc.close();
    });

    test('turning sunrise on adds it to the schedule', () async {
      final h = PrayerHarness(now: DateTime(2026, 10, 3, 3));
      final bloc = await _started(h);
      expect(h.scheduler.scheduled.any((r) => r.prayer == PrayerId.sunrise), isFalse);
      bloc.add(const PrayerAlertCycled(PrayerId.sunrise)); // silent -> sound
      await _settle();
      expect(h.scheduler.scheduled.any((r) => r.prayer == PrayerId.sunrise), isTrue);
      await bloc.close();
    });

    test('a failed write keeps the change on screen and warns once', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      h.prefs.failSave = true;
      bloc.add(const PrayerAlertCycled(PrayerId.fajr));
      await _settle();
      expect(_s(bloc).prefs.modeOf(PrayerId.fajr), AlertMode.vibrate);
      expect(_s(bloc).saveFailed, isTrue);
      expect(_s(bloc).saveSeq, 1);
      h.prefs.failSave = false;
      bloc.add(const PrayerAlertCycled(PrayerId.fajr));
      await _settle();
      expect(_s(bloc).saveFailed, isFalse);
      await bloc.close();
    });

    test('with notifications denied, changes save but nothing is scheduled',
        () async {
      final h = PrayerHarness(permission: NotificationPermission.denied);
      final bloc = await _started(h);
      bloc.add(const PrayerAlertCycled(PrayerId.fajr));
      await _settle();
      expect(h.prefs.value.modeOf(PrayerId.fajr), AlertMode.vibrate);
      expect(h.scheduler.scheduled, isEmpty);
      expect(_s(bloc).syncOutcome, SyncOutcome.permissionDenied);
      await bloc.close();
    });
  });

  group('settings', () {
    test('calculation method recalculates the day', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final before = _s(bloc).day.fajr;
      bloc.add(PrayerSettingsChanged(
        _s(bloc).prefs.copyWith(method: CalcMethod.muslimWorldLeague),
      ));
      await _settle();
      expect(_s(bloc).day.fajr, before.add(const Duration(minutes: 3)));
      expect(h.prefs.value.method, CalcMethod.muslimWorldLeague);
      await bloc.close();
    });

    test('Asr school recalculates the day', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final before = _s(bloc).day.asr;
      bloc.add(PrayerSettingsChanged(
        _s(bloc).prefs.copyWith(madhab: AsrMadhab.hanafi),
      ));
      await _settle();
      expect(_s(bloc).day.asr, before.add(const Duration(minutes: 30)));
      await bloc.close();
    });

    test('settings also recalculate the month table', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerViewChanged(PrayerView.month));
      await _settle();
      final before = _s(bloc).month!.days.first.day.asr;
      bloc.add(PrayerSettingsChanged(
        _s(bloc).prefs.copyWith(madhab: AsrMadhab.hanafi),
      ));
      await _settle();
      expect(_s(bloc).month!.days.first.day.asr,
          before.add(const Duration(minutes: 30)));
      await bloc.close();
    });

    test('pre-alert minutes add earlier reminders', () async {
      final h = PrayerHarness(now: DateTime(2026, 10, 3, 3));
      final bloc = await _started(h);
      expect(h.scheduler.scheduled.any((r) => r.isPreAlert), isFalse);
      bloc.add(PrayerSettingsChanged(_s(bloc).prefs.copyWith(preAlertMinutes: 15)));
      await _settle();
      expect(h.scheduler.scheduled.any((r) => r.isPreAlert), isTrue);
      expect(h.prefs.value.preAlertMinutes, 15);
      await bloc.close();
    });
  });

  group('location choice', () {
    test('picking a city uses it, persists it and recalculates', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final before = _s(bloc).day.dhuhr;
      bloc.add(const PrayerCitySelected('riyadh'));
      await _settle();
      final s = _s(bloc);
      expect(s.resolved.location.name, 'الرياض');
      expect(s.prefs.cityId, 'riyadh');
      expect(h.prefs.value.cityId, 'riyadh');
      expect(s.day.dhuhr.isBefore(before), isTrue, reason: 'east of Makkah');
      await bloc.close();
    });

    test('a manual city keeps working with the GPS refused', () async {
      final h = PrayerHarness(fix: const LocationDenied());
      final bloc = await _started(h);
      bloc.add(const PrayerCitySelected('jeddah'));
      await _settle();
      expect(_s(bloc).resolved.isFallback, isFalse);
      expect(_s(bloc).resolved.location.name, 'جدة');
      await bloc.close();
    });

    test('choosing "automatic" asks for the GPS again', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      bloc.add(const PrayerCitySelected('riyadh'));
      await _settle();
      final asks = h.location.asked.length;
      bloc.add(const PrayerCitySelected(null));
      await _settle();
      expect(h.location.asked.length, asks + 1);
      expect(h.location.asked.last, isTrue, reason: 'explicit user action');
      expect(_s(bloc).prefs.cityId, isNull);
      expect(_s(bloc).resolved.location.name, 'موقعك الحالي');
      await bloc.close();
    });

    test('retrying after a denial that was later granted works', () async {
      final h = PrayerHarness(fix: const LocationDenied());
      final bloc = await _started(h);
      expect(_s(bloc).resolved.isFallback, isTrue);
      h.location.fix = const LocationFound(24.7136, 46.6753);
      bloc.add(const PrayerCitySelected(null));
      await _settle();
      expect(_s(bloc).resolved.isFallback, isFalse);
      expect(_s(bloc).resolved.location.latitude, 24.7136);
      await bloc.close();
    });

    test('a city change re-plans reminders for the new place', () async {
      final h = PrayerHarness();
      final bloc = await _started(h);
      final calls = h.scheduler.replaceCalls;
      bloc.add(const PrayerCitySelected('riyadh'));
      await _settle();
      expect(h.scheduler.replaceCalls, calls + 1);
      expect(h.scheduler.scheduled.first.body, contains('الرياض'));
      await bloc.close();
    });

    test('open-settings is forwarded to the location service', () async {
      final h = PrayerHarness(fix: const LocationDeniedForever());
      final bloc = await _started(h);
      bloc.add(const PrayerOpenSettingsRequested());
      await _settle();
      expect(h.location.settingsOpened, 1);
      await bloc.close();
    });
  });

  group('notifications', () {
    test('the enable button shows the prompt and schedules on success', () async {
      final h = PrayerHarness(permission: NotificationPermission.notDetermined);
      h.prefs.value = h.prefs.value.copyWith(notificationsPrompted: true);
      final bloc = await _started(h);
      expect(_s(bloc).notifications, NotificationPermission.notDetermined);
      expect(h.scheduler.scheduled, isEmpty);

      bloc.add(const PrayerNotificationsRequested());
      await _settle();
      expect(h.scheduler.requests, 1);
      expect(_s(bloc).notifications, NotificationPermission.granted);
      expect(_s(bloc).syncOutcome, SyncOutcome.scheduled);
      expect(h.scheduler.scheduled, isNotEmpty);
      await bloc.close();
    });

    test('a refusal is reported', () async {
      final h = PrayerHarness(permission: NotificationPermission.notDetermined);
      h.prefs.value = h.prefs.value.copyWith(notificationsPrompted: true);
      h.scheduler.onRequest = NotificationPermission.denied;
      final bloc = await _started(h);
      bloc.add(const PrayerNotificationsRequested());
      await _settle();
      expect(_s(bloc).notifications, NotificationPermission.denied);
      expect(_s(bloc).syncOutcome, SyncOutcome.permissionDenied);
      await bloc.close();
    });
  });

  test('refreshReminders (app-open) never prompts and keeps the plan current',
      () async {
    final h = PrayerHarness(permission: NotificationPermission.notDetermined);
    await h.module.refreshReminders();
    expect(h.scheduler.requests, 0);
    expect(h.location.asked, [false]);
    expect(h.scheduler.replaceCalls, 0, reason: 'not allowed yet');

    h.scheduler.current = NotificationPermission.granted;
    await h.module.refreshReminders();
    expect(h.scheduler.replaceCalls, 1);
    expect(h.scheduler.scheduled, isNotEmpty);
  });

  test('refreshReminders swallows scheduler failures', () async {
    final h = PrayerHarness()..scheduler.throwOnReplace = true;
    await h.module.refreshReminders(); // must not throw
  });
}
