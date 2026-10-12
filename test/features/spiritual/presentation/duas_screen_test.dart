import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/features/spiritual/di/tasbeeh_module.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_filter.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_user_data.dart';
import 'package:seen_booking/features/spiritual/domain/utils/dua_text.dart';
import 'package:seen_booking/features/spiritual/presentation/duas/dua_card.dart';
import 'package:seen_booking/features/spiritual/presentation/duas/duas_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/tasbeeh/tasbeeh_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_chip_row.dart';

import '../support/quran_harness.dart' show disposeTree, pumpHub;
import '../support/remembrance_fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  DuaHarness h, {
  double textScale = 1,
  Size size = const Size(390, 844),
}) =>
    pumpHub(
      tester,
      DuasScreen(module: h.module),
      textScale: textScale,
      size: size,
    );

/// A filter chip (the same words also appear on the cards as categories).
Finder _chip(String label) => find.descendant(
      of: find.byType(SpiritualChipRow<DuaFilter>),
      matching: find.text(label),
    );

/// Taps a chip, scrolling the row to it first (the row scrolls sideways and
/// builds chips lazily).
Future<void> _selectChip(WidgetTester tester, String label) async {
  await _revealChip(tester, label);
  await tester.tap(_chip(label));
  await tester.pumpAndSettle();
}

Future<void> _revealChip(WidgetTester tester, String label) async {
  if (_chip(label).evaluate().isEmpty) {
    final scrollable = find.descendant(
      of: find.byType(SpiritualChipRow<DuaFilter>),
      matching: find.byType(Scrollable),
    );
    // Start from the first chip, then scroll along the row.
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (_chip(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(_chip(label), 80, scrollable: scrollable);
    }
  }
  await tester.ensureVisible(_chip(label));
  await tester.pumpAndSettle();
}

Finder _card(String id) => find.byKey(ValueKey(id));

Future<void> _open(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

const _a = 'دعاء السفر التجريبي';
const _b = 'تلبية تجريبية';
const _c = 'ذكر الصباح التجريبي';
const _d = 'دعاء جامع تجريبي';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => loadAppFonts());

  group('list and chips', () {
    testWidgets('shows the five chips from the design plus "saved", and every dua',
        (tester) async {
      await _pump(tester, DuaHarness());
      for (final label in [
        SpiritualStrings.filterAll,
        SpiritualStrings.filterHajj,
        SpiritualStrings.filterSafar,
        SpiritualStrings.filterAdhkar,
        SpiritualStrings.filterJawami,
        SpiritualStrings.filterSaved,
      ]) {
        await _revealChip(tester, label);
        expect(_chip(label), findsOneWidget, reason: label);
      }
      for (final t in [_a, _b, _c, _d]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await disposeTree(tester);
    });

    testWidgets('each card shows its source badge and category', (tester) async {
      await _pump(tester, DuaHarness());
      expect(find.text('صحيح مسلم'), findsOneWidget);
      expect(find.text('متفق عليه'), findsOneWidget);
      expect(find.text('صحيح البخاري'), findsOneWidget);
      expect(
        find.descendant(of: _card('a'), matching: find.text(SpiritualStrings.filterSafar)),
        findsOneWidget,
      );
      await disposeTree(tester);
    });

    testWidgets('collapsed text is clamped to two lines', (tester) async {
      final long = Dua(
        id: 'a',
        category: DuaCategory.safar,
        title: _a,
        text: 'كلمة ' * 80,
        isQuranic: false,
        source: 'مصدر',
        reviewed: true,
      );
      await _pump(tester, DuaHarness(duas: [long]));
      final text = tester.widget<Text>(
        find.descendant(of: _card('a'), matching: find.text(long.text)),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      await disposeTree(tester);
    });

    testWidgets('a chip narrows the list', (tester) async {
      await _pump(tester, DuaHarness());
      await _selectChip(tester, SpiritualStrings.filterHajj);
      expect(find.text(_b), findsOneWidget);
      expect(find.text(_a), findsNothing);
      expect(find.text(_c), findsNothing);

      await _selectChip(tester, SpiritualStrings.filterSafar);
      expect(find.text(_a), findsOneWidget);
      expect(find.text(_b), findsNothing);

      await _selectChip(tester, SpiritualStrings.filterAll);
      expect(find.text(_a), findsOneWidget);
      expect(find.text(_b), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the last chip is remembered across visits', (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _selectChip(tester, SpiritualStrings.filterAdhkar);
      await disposeTree(tester);

      await _pump(tester, h);
      expect(find.text(_c), findsOneWidget);
      expect(find.text(_a), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('a restored chip that is off screen is scrolled into view',
        (tester) async {
      await _pump(
        tester,
        DuaHarness(initial: const DuaUserData(filter: DuaFilter.saved)),
      );
      final chip = _chip(SpiritualStrings.filterSaved);
      final x = tester.getCenter(chip).dx;
      expect(x, inInclusiveRange(0, 390), reason: 'the selected chip is on screen');
      await disposeTree(tester);
    });

    testWidgets('unreviewed duas carry a tag in debug', (tester) async {
      await _pump(tester, DuaHarness());
      expect(
        find.descendant(
          of: _card('d'),
          matching: find.text(SpiritualStrings.duaUnderReview),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _card('a'),
          matching: find.text(SpiritualStrings.duaUnderReview),
        ),
        findsNothing,
        reason: 'reviewed duas are untagged',
      );
      await disposeTree(tester);
    });

    testWidgets('release gating: unreviewed duas are not shown at all', (tester) async {
      await _pump(tester, DuaHarness(includeUnreviewed: false));
      expect(find.text(_d), findsNothing);
      expect(find.text(SpiritualStrings.duaUnderReview), findsNothing);
      expect(find.text(_a), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('nothing reviewed yet: a calm empty message', (tester) async {
      await _pump(tester, DuaHarness(duas: [sampleDuas.last], includeUnreviewed: false));
      expect(find.text(SpiritualStrings.duasEmptyAll), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a load failure offers a retry', (tester) async {
      await _pump(tester, DuaHarness(failDuas: true));
      expect(find.text(SpiritualStrings.loadFailed), findsOneWidget);
      expect(find.text(SpiritualStrings.retry), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('search', () {
    testWidgets('filters while typing, ignoring tashkeel', (tester) async {
      await _pump(tester, DuaHarness());
      await tester.enterText(find.byType(TextField), 'للسفر');
      await tester.pumpAndSettle();
      expect(find.text(_a), findsOneWidget);
      expect(find.text(_b), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('no match shows a message; clearing brings the list back',
        (tester) async {
      await _pump(tester, DuaHarness());
      await tester.enterText(find.byType(TextField), 'لا شيء مطابق');
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duasEmptySearch), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duasEmptySearch), findsNothing);
      expect(find.text(_a), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('search works together with a chip', (tester) async {
      await _pump(tester, DuaHarness());
      await _selectChip(tester, SpiritualStrings.filterHajj);
      await tester.enterText(find.byType(TextField), 'السفر');
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duasEmptySearch), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('card', () {
    testWidgets('opens on tap with note, audio and the three actions', (tester) async {
      await _pump(tester, DuaHarness());
      expect(find.text(SpiritualStrings.duaShare), findsNothing);
      await _open(tester, _a);
      expect(find.text('يُقال عند الركوب'), findsOneWidget);
      expect(find.text(SpiritualStrings.duaShare), findsOneWidget);
      expect(find.text(SpiritualStrings.duaCopy), findsOneWidget);
      expect(find.text(SpiritualStrings.duaSave), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(of: _card('a'), matching: find.text(sampleDuas.first.text)),
      );
      expect(text.maxLines, isNull, reason: 'the whole text is shown when open');
      await disposeTree(tester);
    });

    testWidgets('only one card is open at a time; tapping again closes it',
        (tester) async {
      await _pump(tester, DuaHarness());
      await _open(tester, _a);
      await _open(tester, _b);
      expect(find.text(SpiritualStrings.duaShare), findsOneWidget);
      expect(
        find.descendant(of: _card('b'), matching: find.text(SpiritualStrings.duaShare)),
        findsOneWidget,
      );
      await _open(tester, _b);
      expect(find.text(SpiritualStrings.duaShare), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('action buttons are at least 52 dp tall', (tester) async {
      await _pump(tester, DuaHarness());
      await _open(tester, _a);
      for (final label in [
        SpiritualStrings.duaShare,
        SpiritualStrings.duaCopy,
        SpiritualStrings.duaSave,
      ]) {
        final box = find.ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedContainer),
        );
        expect(tester.getSize(box.first).height, greaterThanOrEqualTo(52), reason: label);
      }
      await disposeTree(tester);
    });
  });

  group('copy and share', () {
    testWidgets('copy puts the dua and its source on the clipboard, then the label returns',
        (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.text(SpiritualStrings.duaCopy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(h.clipboard.last, duaShareText(sampleDuas.first));
      expect(find.text(SpiritualStrings.duaCopied), findsOneWidget);
      expect(find.text(SpiritualStrings.duaCopy), findsNothing);

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duaCopied), findsNothing);
      expect(find.text(SpiritualStrings.duaCopy), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a clipboard failure is reported, not faked', (tester) async {
      final h = DuaHarness()..clipboard.throws = true;
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.text(SpiritualStrings.duaCopy));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duaCopyFailed), findsOneWidget);
      expect(find.text(SpiritualStrings.duaCopied), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('share hands the title and the text with its source to the sheet',
        (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _open(tester, _b);
      await tester.tap(find.text(SpiritualStrings.duaShare));
      await tester.pumpAndSettle();
      expect(h.sharer.shared.single.subject, _b);
      expect(h.sharer.shared.single.text, duaShareText(sampleDuas[1]));
      await disposeTree(tester);
    });

    testWidgets('a share failure shows a message', (tester) async {
      final h = DuaHarness();
      h.sharer.succeeds = false;
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.text(SpiritualStrings.duaShare));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duaShareFailed), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('bookmarks', () {
    testWidgets('save flips to "saved" and is persisted', (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.text(SpiritualStrings.duaSave));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duaSaved), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(h.userData.data.favorites, {'a'});

      await tester.tap(find.text(SpiritualStrings.duaSaved));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duaSave), findsOneWidget);
      expect(h.userData.data.favorites, isEmpty);
      await disposeTree(tester);
    });

    testWidgets('a saved dua is still saved after leaving and returning', (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _open(tester, _c);
      await tester.tap(find.text(SpiritualStrings.duaSave));
      await tester.pumpAndSettle();
      await disposeTree(tester);

      await _pump(tester, h);
      await _open(tester, _c);
      expect(find.text(SpiritualStrings.duaSaved), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the saved chip lists only favourites, with a hint when empty',
        (tester) async {
      final h = DuaHarness(initial: const DuaUserData(favorites: {'b'}));
      await _pump(tester, h);
      await _selectChip(tester, SpiritualStrings.filterSaved);
      expect(find.text(_b), findsOneWidget);
      expect(find.text(_a), findsNothing);

      // Un-saving removes it from this view.
      await _open(tester, _b);
      await tester.tap(find.text(SpiritualStrings.duaSaved));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duasEmptySaved), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a failed save is undone and reported', (tester) async {
      final h = DuaHarness();
      h.userData.failWrites = true;
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.text(SpiritualStrings.duaSave));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.duaSave), findsOneWidget);
      expect(find.text(SpiritualStrings.duaSaveFailed), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('audio', () {
    testWidgets('play starts the clip; progress and time follow; tap again stops',
        (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _open(tester, _a);
      expect(find.text('٠:٠٣'), findsOneWidget, reason: 'total length');

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(h.player.played, ['assets/audio/duas/mock_silence.wav']);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      h.player.position(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      expect(find.text('٠:٠١'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();
      expect(h.player.stops, 1);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('٠:٠٠'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a finished clip returns the button to play', (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      h.player.finish();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('only one clip plays at a time across cards', (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      await _open(tester, _b);
      // Opening b closed a; b's button is a play button, not a pause.
      expect(find.byIcon(Icons.pause), findsNothing);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(h.player.played, hasLength(2));
      expect(find.byIcon(Icons.pause), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a clip that fails to start says so', (tester) async {
      final h = DuaHarness();
      h.player.failPlay = true;
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.audioUnavailable), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('leaving the screen stops the audio', (tester) async {
      final h = DuaHarness();
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      final stops = h.player.stops;
      await disposeTree(tester);
      await tester.pumpAndSettle();
      expect(h.player.stops, greaterThan(stops));
    });

    testWidgets('a dua without a clip has no audio row', (tester) async {
      await _pump(tester, DuaHarness());
      await _open(tester, _d);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.text(SpiritualStrings.duaShare), findsOneWidget);
      await disposeTree(tester);
    });
  });

  testWidgets('the tasbeeh shortcut opens the tasbeeh', (tester) async {
    final previous = TasbeehModule.instance;
    TasbeehModule.instance = TasbeehHarness().module;
    addTearDown(() => TasbeehModule.instance = previous);

    await _pump(tester, DuaHarness());
    await tester.tap(find.byIcon(Icons.blur_circular));
    await tester.pumpAndSettle();
    expect(find.byType(TasbeehScreen), findsOneWidget);
    expect(find.text(SpiritualStrings.tasbeehTitle), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('category labels cover every category', () {
    for (final c in DuaCategory.values) {
      expect(duaCategoryLabel(c), isNotEmpty);
    }
  });

  group('layout', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow with an open card at text scale $scale', (tester) async {
        await _pump(tester, DuaHarness(), textScale: scale);
        await _open(tester, _a);
        expect(tester.takeException(), isNull);
        await disposeTree(tester);
      });
    }
  });

  group('goldens', () {
    testWidgets('list', (tester) async {
      await _pump(tester, DuaHarness(initial: const DuaUserData(favorites: {'b'})));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_duas_list.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('open card, playing', (tester) async {
      final h = DuaHarness(initial: const DuaUserData(favorites: {'a'}));
      await _pump(tester, h);
      await _open(tester, _a);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      h.player.position(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_duas_open.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('empty saved view', (tester) async {
      await _pump(
        tester,
        DuaHarness(initial: const DuaUserData(filter: DuaFilter.saved)),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_duas_saved_empty.png'),
      );
      await disposeTree(tester);
    });
  });
}
