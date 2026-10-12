import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/core/arabic_digits.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_view_prefs.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_ayah_tile.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_page_reader.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_reader_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/theme/spiritual_tokens.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/auto_read.dart';

import '../support/fakes.dart' show FakeScreenAwake;
import '../support/quran_harness.dart';

final _awake = FakeScreenAwake();

Future<void> _pump(
  WidgetTester tester,
  QuranHarness h, {
  int surah = 1,
  int ayah = 1,
  double textScale = 1,
}) =>
    pumpHub(
      tester,
      QuranReaderScreen(
        surah: surah,
        ayah: ayah,
        module: h.module,
        screenAwake: _awake,
      ),
      textScale: textScale,
    );

QuranHarness _pagesHarness() {
  final h = QuranHarness();
  h.viewPrefs.prefs = const ReaderViewPrefs(pages: true);
  return h;
}

Finder _icon(IconData i) => find.byIcon(i);

void main() {
  setUpAll(QuranHarness.preload);

  group('page data', () {
    test('the 604 pages together hold every ayah exactly once, in order', () {
      final d = QuranHarness.data;
      var count = 0;
      int? prevSurah;
      int prevAyah = 0;
      for (var p = 1; p <= 604; p++) {
        final ayahs = d.ayahsOnPage(p);
        expect(ayahs, isNotEmpty, reason: 'page $p');
        for (final a in ayahs) {
          expect(a.page, p, reason: '${a.surah}:${a.number}');
          if (prevSurah == a.surah) {
            expect(a.number, prevAyah + 1);
          }
          prevSurah = a.surah;
          prevAyah = a.number;
          count++;
        }
      }
      expect(count, d.ayahCount);
    });

    test('page 1 is Al-Fatihah and page 604 ends with An-Nas', () {
      final d = QuranHarness.data;
      expect(d.ayahsOnPage(1).first.surah, 1);
      expect(d.ayahsOnPage(604).last.surah, 114);
    });
  });

  group('opening', () {
    testWidgets('defaults to the ayah list', (tester) async {
      final h = QuranHarness();
      await _pump(tester, h);
      expect(find.byType(QuranAyahTile), findsWidgets);
      expect(find.byType(MushafPageView), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('opens as pages when that was the last choice', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h);
      expect(find.byType(MushafPageView), findsWidgets);
      expect(find.byType(QuranAyahTile), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('opens on the page that holds the requested ayah', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 18, ayah: 10);
      final page = QuranHarness.data.ayah(18, 10)!.page;
      expect(find.text(toArabicDigits(page)), findsWidgets);
      await disposeTree(tester);
    });
  });

  group('page view', () {
    testWidgets('a surah start shows the banner and the basmala', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      expect(find.text('سورة البقرة'), findsOneWidget);
      final basmala = QuranHarness.data.ayah(1, 1)!.text;
      expect(find.text(basmala), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('top shows the juz and the surah of the page; bottom the page number',
        (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      expect(find.text('الجزء ١'), findsOneWidget);
      expect(find.text('البقرة'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('swiping turns the page and saves the position after a pause',
        (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      expect(h.reader.lastReadSaves, 0);
      // RTL: the next page lies to the left, so the content is dragged rightwards.
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(h.reader.lastReadSaves, 1);
      final first = QuranHarness.data.ayahsOnPage(3).first;
      expect(h.reader.state.lastRead!.surah, first.surah);
      expect(h.reader.state.lastRead!.ayah, first.number);
      await disposeTree(tester);
    });

    testWidgets('leaving right after a swipe still saves the position', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      await disposeTree(tester);
      await tester.pumpAndSettle();
      expect(h.reader.lastReadSaves, 1);
    });

    testWidgets('font buttons resize the text and are remembered', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(_icon(Icons.text_increase));
      await tester.pumpAndSettle();
      expect(h.reader.state.fontStep, 3);
      await tester.tap(_icon(Icons.text_decrease));
      await tester.tap(_icon(Icons.text_decrease));
      await tester.pumpAndSettle();
      expect(h.reader.state.fontStep, 1);
      await disposeTree(tester);
    });

    testWidgets('uses the app theme: light paper, never black', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      final bg = tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;
      expect(bg, SpiritualTokens.light.bgReader);
      expect(bg.computeLuminance(), greaterThan(0.8));
      // No dark/night switch any more.
      expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
      expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('bookmarking a page toggles the first ayah on it', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(_icon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      expect(h.reader.state.bookmarks.single.surah, 1 + 1);
      expect(h.reader.state.bookmarks.single.ayah, 1);
      expect(_icon(Icons.bookmark), findsOneWidget);
      await tester.tap(_icon(Icons.bookmark));
      await tester.pumpAndSettle();
      expect(h.reader.state.bookmarks, isEmpty);
      await disposeTree(tester);
    });
  });

  group('switching style in place', () {
    testWidgets('list -> pages -> list keeps the position and remembers the choice',
        (tester) async {
      final h = QuranHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(_icon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPageView), findsWidgets);
      expect(h.viewPrefs.prefs.pages, isTrue);

      await tester.tap(_icon(Icons.view_agenda_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(QuranAyahTile), findsWidgets);
      expect(find.text('سورة البقرة'), findsOneWidget);
      expect(h.viewPrefs.prefs.pages, isFalse);
      await disposeTree(tester);
    });

    testWidgets('switching from a later page opens the list at that page\'s first ayah',
        (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      final first = QuranHarness.data.ayahsOnPage(3).first;
      await tester.tap(_icon(Icons.view_agenda_outlined));
      await tester.pumpAndSettle();
      expect(first.surah, 2);
      expect(find.byType(QuranAyahTile), findsWidgets);
      await disposeTree(tester);
    });
  });

  group('hands-free reading: pages', () {
    setUp(() => _awake.reset());

    testWidgets('play starts it: speeds appear, the screen stays awake',
        (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      expect(find.byType(AutoReadSpeedPicker), findsNothing);
      await tester.tap(_icon(Icons.play_circle_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AutoReadSpeedPicker), findsOneWidget);
      expect(_awake.held, isTrue);
      expect(_icon(Icons.pause_circle_outline), findsOneWidget);
      await tester.tap(_icon(Icons.pause_circle_outline));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AutoReadSpeedPicker), findsNothing);
      expect(_awake.held, isFalse);
      await disposeTree(tester);
    });

    testWidgets('the page turns by itself after its reading time', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(_icon(Icons.play_circle_outline));
      // Slow pace: a page that fits is shown for a while, not turned at once.
      await tester.pump(const Duration(seconds: 5));
      expect(h.reader.lastReadSaves, 0, reason: 'still on page 2');
      // Long enough for the dwell on page 2 and the turn.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(seconds: 3));
      final first = QuranHarness.data.ayahsOnPage(3).first;
      expect(h.reader.state.lastRead!.ayah >= first.number, isTrue,
          reason: 'moved on to a later page');
      expect(_awake.held, isTrue, reason: 'still reading');
      await disposeTree(tester);
    });

    testWidgets('touching the page takes over and stops it', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(_icon(Icons.play_circle_outline));
      await tester.pump(const Duration(seconds: 1));
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.byType(AutoReadSpeedPicker), findsNothing);
      expect(_awake.held, isFalse);
      await disposeTree(tester);
    });

    testWidgets('leaving the screen releases the wakelock', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(_icon(Icons.play_circle_outline));
      await tester.pump(const Duration(seconds: 1));
      expect(_awake.held, isTrue);
      await disposeTree(tester);
      expect(_awake.held, isFalse);
    });

    testWidgets('a tall page (large text) scrolls down while it reads', (tester) async {
      final h = _pagesHarness();
      h.reader.state = const ReaderState(fontStep: 5);
      await _pump(tester, h, surah: 2, ayah: 17);
      final scroll = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical);
      double offset() => tester.state<ScrollableState>(scroll.first).position.pixels;
      expect(offset(), 0);
      await tester.tap(_icon(Icons.play_circle_outline));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(offset(), greaterThan(60), reason: '10 s at ~14 px/s');
      await disposeTree(tester);
    });

    testWidgets('faster speeds move faster', (tester) async {
      double travelled = 0;
      for (final speed in [AutoReadSpeed.slow, AutoReadSpeed.fast]) {
        final h = _pagesHarness();
        h.reader.state = const ReaderState(fontStep: 5);
        await _pump(tester, h, surah: 2, ayah: 17);
        await tester.tap(_icon(Icons.play_circle_outline));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400)); // size animation
        await tester.tap(find.text(speed.label));
        await tester.pump();
        final scroll = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        final now = tester.state<ScrollableState>(scroll.first).position.pixels;
        expect(now, greaterThan(travelled), reason: speed.name);
        travelled = now;
        await disposeTree(tester);
      }
    });
  });

  group('hands-free reading: ayah list', () {
    setUp(() => _awake.reset());

    testWidgets('the list scrolls down slowly by itself', (tester) async {
      final h = QuranHarness();
      await _pump(tester, h, surah: 2);
      final scroll = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      double offset() => tester.state<ScrollableState>(scroll.first).position.pixels;
      expect(offset(), 0);
      await tester.tap(find.text(SpiritualStrings.autoShort));
      await tester.pump();
      expect(_awake.held, isTrue);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(offset(), closeTo(140, 25), reason: '10 s at 14 px/s');
      // Pause: it stops where it is.
      await tester.tap(find.text(SpiritualStrings.autoStop).first);
      await tester.pump();
      final stopped = offset();
      await tester.pump(const Duration(seconds: 3));
      expect(offset(), stopped);
      expect(_awake.held, isFalse);
      await disposeTree(tester);
    });

    testWidgets('dragging the text stops it', (tester) async {
      final h = QuranHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(find.text(SpiritualStrings.autoShort));
      await tester.pump(const Duration(seconds: 2));
      await tester.drag(find.byType(ListView), const Offset(0, -80));
      await tester.pump();
      expect(find.text(SpiritualStrings.autoShort), findsOneWidget);
      expect(_awake.held, isFalse);
      await disposeTree(tester);
    });

    testWidgets('the position it reaches is saved', (tester) async {
      final h = QuranHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(find.text(SpiritualStrings.autoShort));
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await disposeTree(tester);
      await tester.pumpAndSettle();
      expect(h.reader.lastReadSaves, greaterThanOrEqualTo(1));
    });

    testWidgets('leaving the screen releases the wakelock', (tester) async {
      final h = QuranHarness();
      await _pump(tester, h, surah: 2);
      await tester.tap(find.text(SpiritualStrings.autoShort));
      await tester.pump(const Duration(seconds: 1));
      await disposeTree(tester);
      expect(_awake.held, isFalse);
    });
  });

  group('layout', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow at text scale $scale', (tester) async {
        final h = _pagesHarness();
        await _pump(tester, h, surah: 2, textScale: scale);
        expect(tester.takeException(), isNull);
        await disposeTree(tester);
      });
    }

    testWidgets('bar buttons are at least 48 dp', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      for (final i in [
        Icons.arrow_back,
        Icons.bookmark_border,
        Icons.play_circle_outline,
        Icons.view_agenda_outlined,
        Icons.text_decrease,
        Icons.text_increase,
      ]) {
        final box = find.ancestor(of: _icon(i), matching: find.byType(SizedBox)).first;
        final s = tester.getSize(box);
        expect(s.width, greaterThanOrEqualTo(48), reason: '$i');
        expect(s.height, greaterThanOrEqualTo(48), reason: '$i');
      }
      await disposeTree(tester);
    });
  });

  group('goldens', () {
    testWidgets('page 470 (Ghafir) in the app theme', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 40, ayah: 26);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_quran_page_470.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('page with a surah banner (Al-Baqarah)', (tester) async {
      final h = _pagesHarness();
      await _pump(tester, h, surah: 2);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_quran_page_banner.png'),
      );
      await disposeTree(tester);
    });
  });

  test('strings exist', () {
    expect(SpiritualStrings.readerPagesView, isNotEmpty);
  });
}
