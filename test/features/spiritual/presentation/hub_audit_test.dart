// M8 cross-cutting audit: every dashboard tile reaches its live screen and
// comes back, every screen survives 2.0 text scale and meets the tap-target
// and label guidelines, and leaving a screen (or flipping to Agent mode)
// releases timers, sensors, audio and the wakelock.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/data/repositories/mock_dashboard_repository.dart';
import 'package:seen_booking/features/spiritual/di/dua_module.dart';
import 'package:seen_booking/features/spiritual/di/prayer_module.dart';
import 'package:seen_booking/features/spiritual/di/quran_module.dart';
import 'package:seen_booking/features/spiritual/di/tasbeeh_module.dart';
import 'package:seen_booking/features/spiritual/domain/entities/app_mode.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_dashboard_usecase.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/dashboard/dashboard_view.dart';
import 'package:seen_booking/features/spiritual/presentation/duas/duas_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/prayer/prayer_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/qibla/qibla_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_index_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_reader_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/shell/mode_shell.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/tasbeeh/tasbeeh_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/tawaf/tawaf_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/prayer_fakes.dart';
import '../support/quran_harness.dart';
import '../support/remembrance_fakes.dart';
import 'mode_cubit_test.dart' show FakeModeRepository;

final _now = DateTime(2026, 10, 3, 11, 40);

/// Every live module wired to in-memory fakes.
class _Hub {
  _Hub({AppMode mode = AppMode.manasik})
      : modeRepo = FakeModeRepository(mode),
        quran = QuranHarness(),
        prayer = PrayerHarness(now: _now),
        duas = DuaHarness(),
        tasbeeh = TasbeehHarness(start: _now);

  final FakeModeRepository modeRepo;
  final QuranHarness quran;
  final PrayerHarness prayer;
  final DuaHarness duas;
  final TasbeehHarness tasbeeh;
  int clockReads = 0;

  late final QuranModule _q = QuranModule.instance;
  late final PrayerModule _p = PrayerModule.instance;
  late final DuaModule _d = DuaModule.instance;
  late final TasbeehModule _t = TasbeehModule.instance;

  void install() {
    // Touch the lazies so the previous instances are remembered.
    _q;
    _p;
    _d;
    _t;
    QuranModule.instance = quran.module;
    PrayerModule.instance = prayer.module;
    DuaModule.instance = duas.module;
    TasbeehModule.instance = tasbeeh.module;
  }

  void restore() {
    QuranModule.instance = _q;
    PrayerModule.instance = _p;
    DuaModule.instance = _d;
    TasbeehModule.instance = _t;
  }

  Widget app(
          {double textScale = 1,
          Duration tick = const Duration(seconds: 30)}) =>
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: ModeShell(
          agentHome: const Center(child: Text('AGENT-HOME')),
          repository: modeRepo,
          createDashboardCubit: () => DashboardCubit(
            GetDashboardUseCase(
              MockDashboardRepository(
                clock: () => _now,
                sessions: InMemoryTawafRepo(),
                readerState: quran.reader,
                quran: QuranHarness.sharedQuran,
              ),
            ),
            clock: () {
              clockReads++;
              return _now;
            },
            tickInterval: tick,
          ),
        ),
      );
}

Future<void> _pumpHub(
  WidgetTester tester,
  _Hub hub, {
  double textScale = 1,
  Duration tick = const Duration(seconds: 30),
}) async {
  await loadHub(tester);
  hub.install();
  addTearDown(hub.restore);
  await tester.pumpWidget(hub.app(textScale: textScale, tick: tick));
  await tester.pumpAndSettle();
}

Future<void> _tapTile(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(
          of: find.byType(DashboardView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  // Sensors/animations on live screens never "settle"; let routes finish.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Hardware / system back, exactly as Android delivers it.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

const _onDashboard = SpiritualStrings.nextPrayer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(QuranHarness.preload);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group(
      'navigation: each tile reaches its live screen and back restores the hub',
      () {
    final tiles = <(String, Type)>[
      (SpiritualStrings.svcQuran, QuranIndexScreen),
      (SpiritualStrings.svcTawaf, TawafScreen),
      (SpiritualStrings.svcDuas, DuasScreen),
      (SpiritualStrings.svcQibla, QiblaScreen),
      (SpiritualStrings.svcPrayer, PrayerScreen),
      (SpiritualStrings.svcTasbeeh, TasbeehScreen),
    ];

    for (final (label, type) in tiles) {
      testWidgets('$label opens $type; system back returns to the dashboard',
          (tester) async {
        final hub = _Hub();
        await _pumpHub(tester, hub);
        await _tapTile(tester, label);
        expect(find.byType(type), findsOneWidget);
        expect(find.text(SpiritualStrings.hubComingSoon), findsNothing,
            reason: 'no placeholder is left');

        await _systemBack(tester);
        expect(find.byType(type), findsNothing, reason: 'screen disposed');
        expect(find.text(_onDashboard), findsOneWidget);
        expect(find.byType(DashboardView), findsOneWidget);
        await disposeTree(tester);
      });
    }

    testWidgets('the on-screen back button also returns', (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub);
      await _tapTile(tester, SpiritualStrings.svcDuas);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DuasScreen), findsNothing);
      expect(find.text(_onDashboard), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the reading card opens the reader on the last-read surah',
        (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub);
      await tester.scrollUntilVisible(
        find.text(SpiritualStrings.continueReading),
        300,
        scrollable: find
            .descendant(
              of: find.byType(DashboardView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text(SpiritualStrings.continueReading));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SpiritualStrings.continueReading));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      await _systemBack(tester);
      expect(find.byType(QuranReaderScreen), findsNothing);
      expect(find.text(_onDashboard), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('open and close every screen in turn: the hub stays intact',
        (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub);
      for (final (label, _) in tiles) {
        await _tapTile(tester, label);
        await _systemBack(tester);
      }
      expect(find.text(_onDashboard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  });

  group('lifecycle: leaving releases timers, sensors, audio and wakelock', () {
    testWidgets('flipping to Agent mode stops the dashboard countdown timer',
        (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub, tick: const Duration(seconds: 1));
      final before = hub.clockReads;
      await tester.pump(const Duration(seconds: 3));
      expect(hub.clockReads, greaterThan(before),
          reason: 'it ticks while visible');

      await tester.tap(find.byIcon(Icons.flip));
      await tester.pumpAndSettle();
      expect(find.text('AGENT-HOME'), findsOneWidget);
      final stopped = hub.clockReads;
      await tester.pump(const Duration(seconds: 10));
      expect(hub.clockReads, stopped,
          reason: 'no ticks once the hub is hidden');
      await disposeTree(tester);
    });

    testWidgets('and it resumes when the user flips back', (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub, tick: const Duration(seconds: 1));
      await tester.tap(find.byIcon(Icons.flip));
      await tester.pumpAndSettle();
      final paused = hub.clockReads;
      await tester.tap(find.byIcon(Icons.flip));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(hub.clockReads, greaterThan(paused));
      await disposeTree(tester);
    });

    testWidgets('switching to another hub tab stops the countdown timer too',
        (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub, tick: const Duration(seconds: 1));
      await tester.tap(find.text(SpiritualStrings.navQuran));
      await tester.pumpAndSettle();
      final stopped = hub.clockReads;
      await tester.pump(const Duration(seconds: 10));
      expect(hub.clockReads, stopped);
      await disposeTree(tester);
    });

    testWidgets('a covered dashboard (a screen on top) does not tick',
        (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub, tick: const Duration(seconds: 1));
      await _tapTile(tester, SpiritualStrings.svcDuas);
      final covered = hub.clockReads;
      await tester.pump(const Duration(seconds: 10));
      expect(hub.clockReads, covered);
      await _systemBack(tester);
      await disposeTree(tester);
    });

    testWidgets('leaving the Qibla screen cancels the compass stream',
        (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub);
      await _tapTile(tester, SpiritualStrings.svcQibla);
      expect(hub.prayer.compass.listeners, 1);
      await _systemBack(tester);
      expect(hub.prayer.compass.listeners, 0);
      await disposeTree(tester);
    });

    testWidgets('leaving the tasbeeh releases the wakelock', (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub);
      await _tapTile(tester, SpiritualStrings.svcTasbeeh);
      expect(hub.tasbeeh.awake.held, isTrue);
      await _systemBack(tester);
      expect(hub.tasbeeh.awake.held, isFalse);
      await disposeTree(tester);
    });

    testWidgets('leaving the duas stops a playing clip', (tester) async {
      final hub = _Hub();
      await _pumpHub(tester, hub);
      await _tapTile(tester, SpiritualStrings.svcDuas);
      await tester.tap(find.text('دعاء السفر التجريبي'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(hub.duas.player.played, isNotEmpty);
      final stops = hub.duas.player.stops;
      await _systemBack(tester);
      expect(hub.duas.player.stops, greaterThan(stops));
      await disposeTree(tester);
    });
  });

  group('accessibility: 2.0 text scale, tap targets, labels', () {
    // Opens [label] from the dashboard at 2x and runs the guidelines on it.
    final screens = <(String, String)>[
      ('Tawaf', SpiritualStrings.svcTawaf),
      ('Duas', SpiritualStrings.svcDuas),
      ('Qibla', SpiritualStrings.svcQibla),
      ('Prayer', SpiritualStrings.svcPrayer),
      ('Tasbeeh', SpiritualStrings.svcTasbeeh),
      ('Quran index', SpiritualStrings.svcQuran),
    ];

    testWidgets('dashboard at 2.0: no overflow, targets >= 48 dp, labelled',
        (tester) async {
      final handle = tester.ensureSemantics();
      final hub = _Hub();
      await _pumpHub(tester, hub, textScale: 2);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await disposeTree(tester);
    });

    for (final (name, tile) in screens) {
      testWidgets('$name at 2.0: no overflow, targets >= 48 dp, labelled',
          (tester) async {
        final handle = tester.ensureSemantics();
        final hub = _Hub();
        await _pumpHub(tester, hub, textScale: 2);
        await _tapTile(tester, tile);
        expect(tester.takeException(), isNull, reason: '$name overflowed');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
        await _systemBack(tester);
        await disposeTree(tester);
      });
    }

    testWidgets('Quran reader at 2.0: no overflow, targets >= 48 dp, labelled',
        (tester) async {
      final handle = tester.ensureSemantics();
      final hub = _Hub();
      await _pumpHub(tester, hub, textScale: 2);
      await tester.scrollUntilVisible(
        find.text(SpiritualStrings.continueReading),
        300,
        scrollable: find
            .descendant(
              of: find.byType(DashboardView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text(SpiritualStrings.continueReading));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SpiritualStrings.continueReading));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await _systemBack(tester);
      await disposeTree(tester);
    });

    testWidgets('an open dua card at 2.0 keeps 48 dp targets and labels',
        (tester) async {
      final handle = tester.ensureSemantics();
      final hub = _Hub();
      await _pumpHub(tester, hub, textScale: 2);
      await _tapTile(tester, SpiritualStrings.svcDuas);
      await tester.tap(find.text('دعاء السفر التجريبي'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await _systemBack(tester);
      await disposeTree(tester);
    });

    testWidgets(
        'the tasbeeh ring speaks as one summary (the dial is covered in qibla_screen_test)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final hub = _Hub();
      await _pumpHub(tester, hub);
      await _tapTile(tester, SpiritualStrings.svcTasbeeh);
      expect(find.bySemanticsLabel(RegExp('العدد')), findsOneWidget);
      handle.dispose();
      await _systemBack(tester);
      await disposeTree(tester);
    });
  });
}
