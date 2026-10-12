import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/domain/entities/rite_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tawaf_session.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/tawaf/tawaf_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/press_scale.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_segmented.dart';

import '../support/fakes.dart';

class _Harness {
  _Harness({TawafSession? stored}) : repo = InMemoryTawafRepo(stored);

  final InMemoryTawafRepo repo;
  final awake = FakeScreenAwake();
  final audio = FakeAudioPlayer();
  final clock = FakeClock();
  final duas = FakeDuaRepository();
}

/// Pushes the screen on top of a root route so `maybePop` has somewhere to go.
Future<void> _pump(
  WidgetTester tester,
  _Harness h, {
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  // Real fonts, so wrapping/overflow match the device (the default test font
  // is far wider than IBM Plex Sans Arabic).
  await loadAppFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TawafScreen(
                    sessionRepository: h.repo,
                    duaRepository: h.duas,
                    audioPlayer: h.audio,
                    screenAwake: h.awake,
                    clock: h.clock.call,
                  ),
                ),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

Future<void> _tapLap(WidgetTester tester, _Harness h) async {
  h.clock.advance(const Duration(seconds: 2));
  await tester.tap(find.byKey(const ValueKey('primary')));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

TawafSession _atLap(int lap, {RiteMode mode = RiteMode.tawaf}) {
  final t0 = DateTime(2026, 10, 3, 13);
  var s = TawafSession.start(mode, t0);
  for (var i = 1; i < lap; i++) {
    s = s.recordLap(t0.add(Duration(minutes: i)));
  }
  return s;
}

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  testWidgets('fresh start: lap 1, Tawaf copy, undo disabled', (tester) async {
    final h = _Harness();
    await _pump(tester, h);
    expect(find.text(SpiritualStrings.tawafOfUmrah), findsOneWidget);
    expect(find.text('١'), findsOneWidget);
    expect(find.text(SpiritualStrings.guideTawafFirst), findsOneWidget);
    expect(find.text('بداية الطواف'), findsOneWidget);
    expect(find.text(SpiritualStrings.btnNext), findsOneWidget);
    expect(find.text(SpiritualStrings.hintTawaf), findsOneWidget);
    expect(find.text(SpiritualStrings.duaTawafLabel), findsOneWidget);
    expect(find.text('دعاء الطواف التجريبي'), findsOneWidget);
    expect(h.repo.stored?.currentLap, 1);
    // The hint stays on one line, so the button keeps its 96 dp height.
    expect(
      tester.getSize(find.text(SpiritualStrings.hintTawaf)).height,
      lessThan(30),
    );
    expect(tester.getSize(find.byKey(const ValueKey('primary'))).height, 96);
    await _end(tester);
  });

  testWidgets('restores a session at the lap it was left on', (tester) async {
    final h = _Harness(stored: _atLap(3));
    await _pump(tester, h);
    expect(find.text('٣'), findsOneWidget);
    expect(find.text('تم تسجيل الشوط ٢'), findsOneWidget);
    expect(find.text(SpiritualStrings.guideTawaf), findsOneWidget);
    await _end(tester);
  });

  testWidgets('a Sa\'i session shows the Sa\'i dua and direction guide',
      (tester) async {
    final h = _Harness(stored: _atLap(2, mode: RiteMode.sai));
    await _pump(tester, h);
    expect(find.text(SpiritualStrings.saiOfUmrah), findsOneWidget);
    expect(find.text(SpiritualStrings.guideSaiEven), findsOneWidget);
    expect(find.text('دعاء السعي التجريبي'), findsOneWidget);
    expect(find.text(SpiritualStrings.hintSai), findsOneWidget);
    await _end(tester);
  });

  group('screen wakelock', () {
    testWidgets('held while the tracker is open, released when it closes',
        (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      expect(h.awake.held, isTrue);
      expect(h.awake.holds, 1);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(h.awake.held, isFalse);
      expect(h.awake.releases, 1);
      await _end(tester);
    });
  });

  group('lap button', () {
    testWidgets('records a lap, persists it and updates the status',
        (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      await _tapLap(tester, h);
      expect(find.text('٢'), findsOneWidget);
      expect(find.text('تم تسجيل الشوط ١'), findsOneWidget);
      expect(h.repo.stored?.currentLap, 2);
      await _end(tester);
    });

    testWidgets('a second tap within 1.5 s is ignored', (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      await _tapLap(tester, h);
      h.clock.advance(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('primary')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('٢'), findsOneWidget, reason: 'still lap 2');
      expect(h.repo.stored?.currentLap, 2);
      await _end(tester);
    });

    testWidgets('lap 7 shows the last-lap label, then the completion state',
        (tester) async {
      final h = _Harness(stored: _atLap(7));
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.btnLast), findsOneWidget);
      await _tapLap(tester, h);
      expect(find.text(SpiritualStrings.tawafDone), findsOneWidget);
      expect(find.text(SpiritualStrings.acceptedTawaf), findsOneWidget);
      expect(find.text(SpiritualStrings.btnToSai), findsOneWidget);
      expect(find.text(SpiritualStrings.hintToSai), findsOneWidget);
      await _end(tester);
    });

    testWidgets('after a finished Tawaf the button starts Sa\'i',
        (tester) async {
      final h = _Harness(stored: _atLap(7));
      await _pump(tester, h);
      await _tapLap(tester, h); // completes
      await _tapLap(tester, h); // go to Sa'i
      expect(find.text(SpiritualStrings.saiOfUmrah), findsOneWidget);
      expect(h.repo.stored?.mode, RiteMode.sai);
      expect(h.repo.stored?.currentLap, 1);
      await _end(tester);
    });
  });

  group('undo confirmation', () {
    testWidgets('is disabled at lap 1', (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.undoLap), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.undoTitle), findsNothing);
      await _end(tester);
    });

    testWidgets('asks first; cancelling keeps the lap', (tester) async {
      final h = _Harness(stored: _atLap(3));
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.undoLap));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.undoTitle), findsOneWidget);
      expect(h.repo.stored?.currentLap, 3, reason: 'nothing happens yet');

      await tester.tap(find.text(SpiritualStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.undoTitle), findsNothing);
      expect(h.repo.stored?.currentLap, 3);
      expect(find.text('٣'), findsOneWidget);
      await _end(tester);
    });

    testWidgets('confirming steps back one lap', (tester) async {
      final h = _Harness(stored: _atLap(3));
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.undoLap));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SpiritualStrings.undoConfirm));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('٢'), findsOneWidget);
      expect(find.text('أُلغي تسجيل الشوط ٢'), findsOneWidget);
      expect(h.repo.stored?.currentLap, 2);
      await _end(tester);
    });

    testWidgets('dismissing by tapping outside counts as cancel',
        (tester) async {
      final h = _Harness(stored: _atLap(3));
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.undoLap));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(h.repo.stored?.currentLap, 3);
      await _end(tester);
    });
  });

  group('finish confirmation', () {
    testWidgets('cancelling leaves the rite untouched', (tester) async {
      final h = _Harness(stored: _atLap(4));
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.finishRite));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.finishTitle), findsOneWidget);
      await tester.tap(find.text(SpiritualStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.tawafOfUmrah), findsOneWidget);
      expect(h.repo.stored?.currentLap, 4);
      expect(h.repo.clears, 0);
      await _end(tester);
    });

    testWidgets('confirming clears the session and closes the screen',
        (tester) async {
      final h = _Harness(stored: _atLap(4));
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.finishRite));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SpiritualStrings.finishConfirm));
      await tester.pumpAndSettle();
      expect(h.repo.stored, isNull);
      expect(find.text(SpiritualStrings.tawafOfUmrah), findsNothing);
      expect(find.text('OPEN'), findsOneWidget, reason: 'back on the root');
      await _end(tester);
    });
  });

  group('mode switch', () {
    testWidgets('with progress it asks before discarding it', (tester) async {
      final h = _Harness(stored: _atLap(3));
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.modeSai));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.switchTitle), findsOneWidget);
      await tester.tap(find.text(SpiritualStrings.cancel));
      await tester.pumpAndSettle();
      expect(h.repo.stored?.mode, RiteMode.tawaf);
      expect(h.repo.stored?.currentLap, 3);

      await tester.tap(find.text(SpiritualStrings.modeSai));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SpiritualStrings.switchConfirm));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(h.repo.stored?.mode, RiteMode.sai);
      expect(h.repo.stored?.currentLap, 1);
      expect(find.text(SpiritualStrings.saiOfUmrah), findsOneWidget);
      await _end(tester);
    });

    testWidgets('with no progress it switches straight away', (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.modeSai));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text(SpiritualStrings.switchTitle), findsNothing);
      expect(h.repo.stored?.mode, RiteMode.sai);
      await _end(tester);
    });
  });

  group('dua audio', () {
    testWidgets('play and stop through the pill', (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.listen), findsOneWidget);

      await tester.tap(find.text(SpiritualStrings.listen));
      await tester.pumpAndSettle();
      expect(h.audio.played, ['assets/audio/duas/mock_silence.wav']);
      expect(find.text(SpiritualStrings.stopAudio), findsOneWidget);

      await tester.tap(find.text(SpiritualStrings.stopAudio));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.listen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('an unplayable asset shows a friendly message',
        (tester) async {
      final h = _Harness();
      h.audio.failPlay = true;
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.listen));
      await tester.pump();
      await tester.pump();
      expect(find.text(SpiritualStrings.audioUnavailable), findsOneWidget);
      expect(find.text(SpiritualStrings.listen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('audio is stopped when the screen is left', (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.listen));
      await tester.pumpAndSettle();
      final stops = h.audio.stops;
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.pump(); // let the cubit's async close() finish
      expect(h.audio.stops, greaterThan(stops));
      await _end(tester);
    });

    testWidgets('switching rite stops the audio', (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.listen));
      await tester.pumpAndSettle();
      final stops = h.audio.stops;
      await tester.tap(find.text(SpiritualStrings.modeSai));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(h.audio.stops, greaterThan(stops));
      await _end(tester);
    });
  });

  testWidgets('a failing disk warns once but the lap still counts',
      (tester) async {
    final h = _Harness();
    await _pump(tester, h);
    h.repo.failSave = true;
    await _tapLap(tester, h);
    expect(find.text('٢'), findsOneWidget);
    expect(find.text(SpiritualStrings.saveFailed), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the status pill flashes after a lap and settles after 1.2 s',
      (tester) async {
    final h = _Harness();
    await _pump(tester, h);
    h.clock.advance(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('primary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Flash timer is pending; letting it run must not throw or leak.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(tester.takeException(), isNull);
    await _end(tester);
  });

  testWidgets('tap targets are at least 48 dp', (tester) async {
    final h = _Harness(stored: _atLap(3));
    await _pump(tester, h);
    for (final label in [
      SpiritualStrings.finishRite,
      SpiritualStrings.undoLap,
      SpiritualStrings.listen,
    ]) {
      final size = tester.getSize(find
          .ancestor(of: find.text(label), matching: find.byType(PressScale))
          .first);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    // Segmented options are 48 tall inside a 56 tall track.
    expect(
      tester.getSize(find.byType(SpiritualSegmented<RiteMode>)).height,
      greaterThanOrEqualTo(56),
    );
    final primary = tester.getSize(find.byKey(const ValueKey('primary')));
    expect(primary.height, greaterThanOrEqualTo(96));
    await _end(tester);
  });

  testWidgets('survives text scale 2.0 without overflow', (tester) async {
    final h = _Harness(stored: _atLap(3));
    await _pump(tester, h, textScale: 2);
    expect(tester.takeException(), isNull);
    await _end(tester);
  });

  testWidgets('golden: lap 3 of 7 @ 390x844 (matches Tawaf.dc.html)',
      (tester) async {
    final h = _Harness(stored: _atLap(3));
    await _pump(tester, h);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/spiritual_tawaf_lap3.png'),
    );
    await _end(tester);
  });

  testWidgets('golden: completed Tawaf', (tester) async {
    final h = _Harness(stored: _atLap(7));
    await _pump(tester, h);
    await _tapLap(tester, h);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/spiritual_tawaf_done.png'),
    );
    await _end(tester);
  });
}
