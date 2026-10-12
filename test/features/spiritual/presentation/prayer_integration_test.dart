import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/data/repositories/live_dashboard_repository.dart';
import 'package:seen_booking/features/spiritual/di/prayer_module.dart';
import 'package:seen_booking/features/spiritual/di/quran_module.dart';
import 'package:seen_booking/features/spiritual/domain/entities/app_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/calc_settings.dart';
import 'package:seen_booking/features/spiritual/domain/entities/day_prayers.dart';
import 'package:seen_booking/features/spiritual/domain/entities/location_fix.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_day.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_location.dart';
import 'package:seen_booking/features/spiritual/domain/entities/rite_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tawaf_session.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_dashboard_usecase.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_state.dart';
import 'package:seen_booking/features/spiritual/presentation/prayer/prayer_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/shell/mode_shell.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';

import '../support/fakes.dart';
import '../support/prayer_fakes.dart';
import '../support/quran_harness.dart';
import 'mode_cubit_test.dart' show FakeModeRepository;

LiveDashboardRepository _live(
  PrayerHarness p, {
  InMemoryTawafRepo? sessions,
  QuranHarness? quran,
}) {
  final q = quran ?? QuranHarness();
  return LiveDashboardRepository(
    prayer: p.module,
    sessions: sessions ?? InMemoryTawafRepo(),
    readerState: q.reader,
    quran: QuranHarness.sharedQuran,
  );
}

void main() {
  setUpAll(QuranHarness.preload);

  group('LiveDashboardRepository', () {
    test('uses the calculated prayer times, location and Hijri date', () async {
      final p = PrayerHarness();
      final s = (await _live(p).load()).getOrElse((_) => throw 'x');
      expect(s.city, 'موقعك الحالي');
      expect(s.hijri.day, 22);
      expect(s.hijri.monthName, 'ربيع الآخر');
      expect(s.hijri.year, 1448);
      expect(s.prayers.times.map((t) => t.slot), PrayerSlot.values);
      expect(s.prayers.times[1].time, DateTime(2026, 10, 3, 12, 15)); // dhuhr
      expect(s.prayers.times[0].time, DateTime(2026, 10, 3, 4, 58)); // fajr
    });

    test('the next prayer comes from the real day', () async {
      final p = PrayerHarness(); // 11:40
      final s = (await _live(p).load()).getOrElse((_) => throw 'x');
      final next = s.prayers.next(p.module.clock());
      expect(next.slot, PrayerSlot.dhuhr);
      expect(next.remainingMinutes, 35);
      expect(next.isTomorrow, isFalse);
    });

    test('after isha the next prayer is the REAL fajr of tomorrow', () async {
      final p = PrayerHarness(now: DateTime(2026, 10, 3, 21));
      final s = (await _live(p).load()).getOrElse((_) => throw 'x');
      final next = s.prayers.next(p.module.clock());
      expect(next.isTomorrow, isTrue);
      expect(next.slot, PrayerSlot.fajr);
      // Tomorrow's fajr differs from "today's + 24 h" (the days drift).
      final naive = s.prayers.times.first.time.add(const Duration(days: 1));
      expect(next.time, isNot(naive));
      expect(next.time.day, 4);
      final prefs = await p.prefs.load();
      expect(
        next.time,
        p.calculator
            .calculate(
              location: SaudiCities.makkah.toLocation(),
              date: DateTime(2026, 10, 4),
              method: prefs.method,
              madhab: prefs.madhab,
            )
            .fajr,
      );
    });

    test('a chosen city is used', () async {
      final p = PrayerHarness();
      await p.prefs.save((await p.prefs.load()).copyWith(cityId: 'riyadh'));
      final s = (await _live(p).load()).getOrElse((_) => throw 'x');
      expect(s.city, 'الرياض');
      expect(
        s.prayers.times[1].time.isBefore(DateTime(2026, 10, 3, 12, 15)),
        isTrue,
      );
    });

    test('with location denied it still works, in Makkah, without prompting',
        () async {
      final p = PrayerHarness(fix: const LocationDenied());
      final s = (await _live(p).load()).getOrElse((_) => throw 'x');
      expect(s.city, 'مكة المكرمة');
      expect(p.location.asked.every((asked) => !asked), isTrue,
          reason: 'the dashboard never shows a permission dialog');
    });

    test('the active rite comes from the stored session', () async {
      final p = PrayerHarness();
      final repo = InMemoryTawafRepo();
      var s = (await _live(p, sessions: repo).load()).getOrElse((_) => throw 'x');
      expect(s.activeRite, isNull);
      repo.stored = TawafSession.start(RiteMode.sai, DateTime(2026, 10, 3));
      s = (await _live(p, sessions: repo).load()).getOrElse((_) => throw 'x');
      expect(s.activeRite?.mode, RiteMode.sai);
    });

    test('the reading card uses the real last-read position', () async {
      final p = PrayerHarness();
      final s = (await _live(p).load()).getOrElse((_) => throw 'x');
      expect(s.reading.surahName, 'الفاتحة');
      expect(s.reading.page, 1);
    });

    test('a failing calculation becomes a Failure, not an exception',
        () async {
      final p = PrayerHarness();
      final module = PrayerModule(
        calculator: _ThrowingCalculator(),
        location: p.location,
        preferences: p.prefs,
        scheduler: p.scheduler,
        clock: p.module.clock,
      );
      final repo = LiveDashboardRepository(
        prayer: module,
        sessions: InMemoryTawafRepo(),
        readerState: QuranHarness().reader,
        quran: QuranHarness.sharedQuran,
      );
      expect((await repo.load()).isLeft(), isTrue);
    });
  });

  group('DayPrayers with a known tomorrow', () {
    final base = DateTime(2026, 10, 3);
    DateTime at(int h, int m) => DateTime(base.year, base.month, base.day, h, m);

    test('uses tomorrowFajr when given, else today + 24 h', () {
      final times = [
        PrayerTime(PrayerSlot.fajr, at(4, 58)),
        PrayerTime(PrayerSlot.dhuhr, at(12, 15)),
        PrayerTime(PrayerSlot.asr, at(15, 37)),
        PrayerTime(PrayerSlot.maghrib, at(18, 4)),
        PrayerTime(PrayerSlot.isha, at(19, 34)),
      ];
      final tomorrow = DateTime(2026, 10, 4, 4, 59);
      final withTomorrow = DayPrayers(times, tomorrowFajr: tomorrow);
      expect(withTomorrow.next(at(22, 0)).time, tomorrow);
      expect(DayPrayers(times).next(at(22, 0)).time, DateTime(2026, 10, 4, 4, 58));
      expect(withTomorrow.next(at(11, 0)).time, at(12, 15),
          reason: 'tomorrow is only used after isha');
    });
  });

  group('dashboard -> prayer screen', () {
    late PrayerModule previousPrayer;
    late QuranModule previousQuran;

    setUp(() {
      previousPrayer = PrayerModule.instance;
      previousQuran = QuranModule.instance;
    });
    tearDown(() {
      PrayerModule.instance = previousPrayer;
      QuranModule.instance = previousQuran;
    });

    Future<PrayerHarness> pumpShell(WidgetTester tester) async {
      final p = PrayerHarness();
      final q = QuranHarness();
      PrayerModule.instance = p.module;
      QuranModule.instance = q.module;
      await loadHub(tester);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: ModeShell(
          agentHome: const Center(child: Text('AGENT-HOME')),
          repository: FakeModeRepository(AppMode.manasik),
          createDashboardCubit: () => DashboardCubit(
            GetDashboardUseCase(_live(p, quran: q)),
            clock: p.module.clock,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return p;
    }

    testWidgets('the dashboard shows the calculated times', (tester) async {
      await pumpShell(tester);
      expect(find.text('موقعك الحالي'), findsOneWidget);
      expect(find.text('متبقي ٠٠:٣٥'), findsOneWidget);
      expect(find.text('١٢:١٥'), findsWidgets);
      await disposeTree(tester);
    });

    testWidgets('the header shows the real Hijri date', (tester) async {
      await pumpShell(tester);
      expect(find.text('٢٢ ربيع الآخر ١٤٤٨'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('tapping the prayer card opens the prayer screen',
        (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text(SpiritualStrings.nextPrayer));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerScreen), findsOneWidget);
      expect(find.text(SpiritualStrings.prayerTitle), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the city button opens it too', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.bySemanticsLabel(RegExp(SpiritualStrings.changeCity)));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerScreen), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the "المواقيت" service opens it', (tester) async {
      await pumpShell(tester);
      await tester.ensureVisible(find.text(SpiritualStrings.svcPrayer));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SpiritualStrings.svcPrayer));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerScreen), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a city chosen there is reflected on the dashboard on return',
        (tester) async {
      final p = await pumpShell(tester);
      await tester.tap(find.text(SpiritualStrings.nextPrayer));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.prayerSettings));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('الرياض'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الرياض'));
      await tester.pumpAndSettle();
      expect((await p.prefs.load()).cityId, 'riyadh');
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerScreen), findsNothing);
      expect(find.text('الرياض'), findsOneWidget, reason: 'dashboard header');
      await disposeTree(tester);
    });
  });

  test('the cubit exposes the live snapshot', () async {
    final p = PrayerHarness();
    final cubit = DashboardCubit(
      GetDashboardUseCase(_live(p)),
      clock: p.module.clock,
      tickInterval: const Duration(hours: 1),
    );
    await cubit.load();
    final s = cubit.state as DashboardLoaded;
    expect(s.next.slot, PrayerSlot.dhuhr);
    await cubit.close();
  });
}

class _ThrowingCalculator extends FixedPrayerCalculator {
  @override
  PrayerDay calculate({
    required PrayerLocation location,
    required DateTime date,
    required CalcMethod method,
    required AsrMadhab madhab,
  }) =>
      throw StateError('astronomy failed');
}
