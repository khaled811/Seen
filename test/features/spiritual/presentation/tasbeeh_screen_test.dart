import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/features/spiritual/core/seen_haptics.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tasbeeh.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/tasbeeh/tasbeeh_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/tasbeeh/tasbeeh_surface.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/progress_ring.dart';

import '../support/quran_harness.dart' show disposeTree, pumpHub;
import '../support/remembrance_fakes.dart';

final _platformCalls = <String>[];
final _patterns = <List<int>>[];

Future<void> _pump(
  WidgetTester tester,
  TasbeehHarness h, {
  double textScale = 1,
  Size size = const Size(390, 844),
}) =>
    pumpHub(
      tester,
      TasbeehScreen(module: h.module),
      textScale: textScale,
      size: size,
    );

/// Pushes the screen on a root route so closing it has somewhere to go.
Future<void> _pushed(WidgetTester tester, TasbeehHarness h) async {
  await pumpHub(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              TasbeehScreen.route(module: h.module),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

/// The big number in the ring (the stats can show the same digits).
Finder _count(String digits) => find.descendant(
      of: find.byType(ProgressRing),
      matching: find.text(digits),
    );

Future<void> _tap(WidgetTester tester, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byType(TasbeehSurface));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => loadAppFonts());

  setUp(() {
    _platformCalls.clear();
    _patterns.clear();
    SeenHaptics.enabled = true;
    SeenHaptics.patternPlayer = (p) async => _patterns.add(p);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        _platformCalls.add(call.arguments as String);
      }
      return null;
    });
  });

  tearDown(() {
    SeenHaptics.patternPlayer = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('opens on the first dhikr: zero of 33, hint, empty stats', (tester) async {
    final h = TasbeehHarness();
    await _pump(tester, h);
    expect(find.text(SpiritualStrings.tasbeehTitle), findsOneWidget);
    expect(find.text('ذكر أول'), findsWidgets);
    expect(_count('٠'), findsOneWidget);
    expect(find.text('/ ٣٣'), findsOneWidget);
    expect(find.text(SpiritualStrings.tapToCount), findsOneWidget);
    expect(find.text(SpiritualStrings.roundsCompleted), findsOneWidget);
    expect(find.text(SpiritualStrings.todayTotal), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('the tap surface is a large target in the middle of the screen', (tester) async {
    final h = TasbeehHarness();
    await _pump(tester, h);
    final size = tester.getSize(find.byType(TasbeehSurface));
    expect(size.width, greaterThan(300));
    expect(size.height, greaterThan(300));
    await disposeTree(tester);
  });

  testWidgets('each tap counts, gives a light haptic and is saved at once', (tester) async {
    final h = TasbeehHarness();
    await _pump(tester, h);
    await _tap(tester, 5);
    expect(_count('٥'), findsOneWidget);
    expect(
      _platformCalls.where((c) => c == 'HapticFeedbackType.selectionClick'),
      hasLength(5),
    );
    expect(h.repo.stored!.count, 5);
    await disposeTree(tester);
  });

  testWidgets('reaching 33 turns the surface green, double-pulses and counts a round',
      (tester) async {
    final h = TasbeehHarness(initial: TasbeehHarness().progress(count: 32));
    await _pump(tester, h);
    _platformCalls.clear();
    await _tap(tester);
    expect(_count('٣٣'), findsOneWidget);
    expect(find.text(SpiritualStrings.roundComplete), findsOneWidget);
    expect(find.text(SpiritualStrings.tapToCount), findsNothing);
    expect(_patterns, [
      [0, 60, 80, 60],
    ], reason: 'the target-reached pattern');
    expect(
      _platformCalls.where((c) => c == 'HapticFeedbackType.selectionClick'),
      isEmpty,
      reason: 'the completing tap is the double pulse, not a plain tick',
    );
    expect(h.repo.stored!.complete, isTrue);
    expect(h.repo.stored!.today.rounds, 1);
    await disposeTree(tester);
  });

  testWidgets('cycle rollover: the next tap starts the new round at 1', (tester) async {
    final h = TasbeehHarness(initial: TasbeehHarness().progress(count: 32));
    await _pump(tester, h);
    await _tap(tester, 2);
    expect(_count('١'), findsOneWidget);
    expect(find.text(SpiritualStrings.tapToCount), findsOneWidget);
    expect(h.repo.stored!.today.rounds, 1);
    expect(h.repo.stored!.today.total, 2);
    await disposeTree(tester);
  });

  testWidgets('target segments: 100 and open', (tester) async {
    final h = TasbeehHarness();
    await _pump(tester, h);
    await tester.tap(find.text('١٠٠'));
    await tester.pumpAndSettle();
    expect(find.text('/ ١٠٠'), findsOneWidget);
    expect(h.repo.stored!.target, TasbeehTarget.hundred);

    await tester.tap(find.text(SpiritualStrings.targetOpen));
    await tester.pumpAndSettle();
    expect(find.text(SpiritualStrings.noLimit), findsOneWidget);
    await _tap(tester, 40);
    expect(_count('٤٠'), findsOneWidget);
    expect(find.text(SpiritualStrings.roundComplete), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('the picker lists the adhkar and switching resets the count', (tester) async {
    final h = TasbeehHarness(initial: TasbeehHarness().progress(count: 7));
    await _pump(tester, h);
    expect(_count('٧'), findsOneWidget);
    await tester.tap(find.text(SpiritualStrings.currentDhikr));
    await tester.pumpAndSettle();
    expect(find.text(SpiritualStrings.pickDhikr), findsOneWidget);
    expect(find.text('ذكر ثان'), findsOneWidget);
    expect(find.text('ذكر ثالث'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'the current one is ticked');

    await tester.tap(find.text('ذكر ثان'));
    await tester.pumpAndSettle();
    expect(find.text(SpiritualStrings.pickDhikr), findsNothing);
    expect(find.text('ذكر ثان'), findsOneWidget);
    expect(_count('٠'), findsOneWidget);
    expect(h.repo.stored!.dhikrId, 'two');
    expect(h.repo.stored!.count, 0);
    await disposeTree(tester);
  });

  testWidgets('reset asks first, and a cancel keeps the count', (tester) async {
    final h = TasbeehHarness(initial: TasbeehHarness().progress(count: 12));
    await _pump(tester, h);
    await tester.tap(find.text(SpiritualStrings.tasbeehReset));
    await tester.pumpAndSettle();
    expect(find.text(SpiritualStrings.tasbeehResetTitle), findsOneWidget);
    await tester.tap(find.text(SpiritualStrings.cancel));
    await tester.pumpAndSettle();
    expect(_count('١٢'), findsOneWidget);
    expect(h.repo.saves, 0, reason: 'nothing changed, nothing written');
    await disposeTree(tester);
  });

  testWidgets('confirming reset zeroes the count and keeps today\'s total', (tester) async {
    final h = TasbeehHarness();
    await _pump(tester, h);
    await _tap(tester, 12);
    _platformCalls.clear();
    await tester.tap(find.text(SpiritualStrings.tasbeehReset));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(Dialog),
      matching: find.text(SpiritualStrings.tasbeehReset),
    ));
    await tester.pumpAndSettle();
    expect(_count('٠'), findsOneWidget);
    expect(h.repo.stored!.count, 0);
    expect(h.repo.stored!.today.total, 12);
    expect(_platformCalls, contains('HapticFeedbackType.mediumImpact'));
    await disposeTree(tester);
  });

  testWidgets('reset at zero does not ask', (tester) async {
    final h = TasbeehHarness();
    await _pump(tester, h);
    await tester.tap(find.text(SpiritualStrings.tasbeehReset));
    await tester.pumpAndSettle();
    expect(find.text(SpiritualStrings.tasbeehResetTitle), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('reopening restores count, target, dhikr and today\'s stats', (tester) async {
    final base = TasbeehHarness();
    final h = TasbeehHarness(
      initial: base.progress(
        dhikrId: 'three',
        target: TasbeehTarget.hundred,
        count: 41,
        daily: const {'three': DhikrDay(total: 141, rounds: 1)},
      ),
    );
    await _pump(tester, h);
    expect(_count('٤١'), findsOneWidget);
    expect(find.text('/ ١٠٠'), findsOneWidget);
    expect(find.text('ذكر ثالث'), findsWidgets);
    expect(find.text('١٤١'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('the screen stays awake while open and is released on close', (tester) async {
    final h = TasbeehHarness();
    await _pushed(tester, h);
    expect(h.awake.held, isTrue);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(TasbeehSurface), findsNothing);
    expect(h.awake.held, isFalse);
    await disposeTree(tester);
  });

  testWidgets('closing the screen mid-count loses nothing', (tester) async {
    final h = TasbeehHarness();
    await _pushed(tester, h);
    await _tap(tester, 9);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(h.repo.stored!.count, 9);
  });

  testWidgets('a failed save keeps counting and says so once', (tester) async {
    final h = TasbeehHarness();
    h.repo.failSave = true;
    await _pump(tester, h);
    await _tap(tester, 3);
    expect(_count('٣'), findsOneWidget);
    expect(find.text(SpiritualStrings.saveFailed), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('no adhkar: a retry message instead of a broken screen', (tester) async {
    final h = TasbeehHarness(catalog: FakeDhikrCatalog(fail: true));
    await _pump(tester, h);
    expect(find.text(SpiritualStrings.loadFailed), findsOneWidget);
    expect(find.text(SpiritualStrings.retry), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('screen readers hear the dhikr and the count', (tester) async {
    final handle = tester.ensureSemantics();
    final h = TasbeehHarness(initial: TasbeehHarness().progress(count: 5));
    await _pump(tester, h);
    expect(find.bySemanticsLabel(RegExp('ذكر أول — العدد ٥')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('الذكر الحالي: ذكر أول')), findsOneWidget);
    handle.dispose();
    await disposeTree(tester);
  });

  group('layout', () {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('no overflow at text scale $scale', (tester) async {
        final h = TasbeehHarness(initial: TasbeehHarness().progress(count: 33, complete: true));
        await _pump(tester, h, textScale: scale);
        expect(tester.takeException(), isNull);
        await disposeTree(tester);
      });
    }

    testWidgets('a small phone scrolls instead of overflowing', (tester) async {
      final h = TasbeehHarness();
      await _pump(tester, h, textScale: 2, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('a 5-digit open count stays inside the ring', (tester) async {
      final h = TasbeehHarness(
        initial: TasbeehHarness().progress(target: TasbeehTarget.open, count: 12345),
      );
      await _pump(tester, h);
      expect(tester.takeException(), isNull);
      expect(_count('١٢٣٤٥'), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('goldens', () {
    testWidgets('counting', (tester) async {
      final h = TasbeehHarness(initial: TasbeehHarness().progress(count: 21));
      await _pump(tester, h);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_tasbeeh_counting.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('round complete', (tester) async {
      final base = TasbeehHarness();
      final h = TasbeehHarness(
        initial: base.progress(
          count: 33,
          complete: true,
          daily: const {'one': DhikrDay(total: 245, rounds: 7)},
        ),
      );
      await _pump(tester, h);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_tasbeeh_complete.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('open count', (tester) async {
      final h = TasbeehHarness(
        initial: TasbeehHarness().progress(target: TasbeehTarget.open, count: 175),
      );
      await _pump(tester, h);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_tasbeeh_open.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('dhikr picker', (tester) async {
      final h = TasbeehHarness();
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.currentDhikr));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_tasbeeh_picker.png'),
      );
      await disposeTree(tester);
    });
  });
}
