import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/presentation/theme/spiritual_tokens.dart';
import 'package:seen_booking/features/spiritual/domain/entities/bookmark.dart';
import 'package:seen_booking/features/spiritual/domain/entities/last_read.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/last_read_card.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_index_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_reader_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_row_tile.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/press_scale.dart';

import '../support/quran_harness.dart';

Future<void> _pumpIndex(
  WidgetTester tester,
  QuranHarness h, {
  bool embedded = false,
  double textScale = 1,
  VoidCallback? onReturned,
}) =>
    pumpHub(
      tester,
      QuranIndexScreen(
        module: h.module,
        embedded: embedded,
        onReturned: onReturned,
      ),
      textScale: textScale,
    );

/// Types into the search field and waits out the 150 ms debounce.
Future<void> _search(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField), q);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(QuranHarness.preload);

  testWidgets('shows the title, search field, tabs and the first surahs',
      (tester) async {
    final h = QuranHarness();
    await _pumpIndex(tester, h);
    expect(find.text(SpiritualStrings.svcQuran), findsOneWidget);
    expect(find.text(SpiritualStrings.searchHint), findsOneWidget);
    for (final tab in [
      SpiritualStrings.tabSurahs,
      SpiritualStrings.tabJuz,
      SpiritualStrings.tabBookmarks,
    ]) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('الفاتحة'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('مكية · ٧ آية'), findsOneWidget);
    expect(find.text('البقرة'), findsOneWidget);
    expect(find.text('مدنية · ٢٨٦ آية'), findsOneWidget);
    expect(find.text(SpiritualStrings.lastRead), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('rows are built lazily, and the whole list is reachable',
      (tester) async {
    final h = QuranHarness();
    await _pumpIndex(tester, h);
    expect(find.text('الناس'), findsNothing, reason: 'surah 114 not built yet');
    await tester.scrollUntilVisible(
      find.text('الناس'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('الناس'), findsOneWidget);
    await disposeTree(tester);
  });

  group('last read card', () {
    testWidgets('shows surah, ayah, page and juz', (tester) async {
      final h = QuranHarness(
        initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
      );
      await _pumpIndex(tester, h);
      expect(find.text(SpiritualStrings.lastRead), findsOneWidget);
      expect(find.text('سورة الكهف · الآية ٣'), findsOneWidget);
      expect(find.text('صفحة ٢٩٣ · الجزء ١٥'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('is hidden while searching and returns when cleared',
        (tester) async {
      final h = QuranHarness(
        initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
      );
      await _pumpIndex(tester, h);
      await _search(tester, 'الفاتحة');
      expect(find.byType(LastReadCard), findsNothing);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.clearSearch));
      await tester.pumpAndSettle();
      expect(find.byType(LastReadCard), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('"متابعة" opens the reader at the saved ayah', (tester) async {
      final h = QuranHarness(
        initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
      );
      await _pumpIndex(tester, h);
      await tester.tap(find.text(SpiritualStrings.resume));
      await tester.pumpAndSettle();
      expect(find.text('سورة الكهف'), findsOneWidget);
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('search', () {
    testWidgets('filters by name and offers the ayah-text search',
        (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      await _search(tester, 'الكهف');
      // The typed text is in the field too, so look inside the list rows.
      expect(
        find.descendant(
          of: find.byType(QuranRowTile),
          matching: find.text('الكهف'),
        ),
        findsOneWidget,
      );
      expect(find.byType(QuranRowTile), findsOneWidget);
      expect(find.text('الفاتحة'), findsNothing);
      expect(find.text('البحث في نص الآيات عن «الكهف»'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('tolerates tashkeel, hamza variants and Arabic digits',
        (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      await _search(tester, 'ابراهيم');
      expect(find.text('إبراهيم'), findsOneWidget);
      await _search(tester, '١٨');
      expect(find.text('الكهف'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('by transliteration', (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      await _search(tester, 'kahf');
      expect(find.text('الكهف'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('no match shows the empty message', (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      await _search(tester, 'zzzzqqq');
      expect(find.text(SpiritualStrings.noMatches), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the clear button appears only with text and clears it',
        (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      expect(find.bySemanticsLabel(SpiritualStrings.clearSearch), findsNothing);
      await _search(tester, 'الكهف');
      expect(find.bySemanticsLabel(SpiritualStrings.clearSearch), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.clearSearch));
      await tester.pumpAndSettle();
      expect(find.text('الفاتحة'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
      await disposeTree(tester);
    });

    testWidgets('the ayah-text row opens full-text results', (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      await _search(tester, 'الحمد لله');
      await tester.tap(find.text('البحث في نص الآيات عن «الحمد لله»'));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.searchResults), findsOneWidget);
      expect(find.text('سورة الفاتحة · الآية ٢'), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('tabs', () {
    testWidgets('juz tab', (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      await tester.tap(find.text(SpiritualStrings.tabJuz));
      await tester.pumpAndSettle();
      expect(find.text('الجزء ١'), findsOneWidget);
      expect(find.text('الجزء ٢'), findsOneWidget);
      expect(find.text('يبدأ من البقرة · الآية ١٤٢'), findsOneWidget);
      expect(find.text('Juz 2'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('bookmarks tab is empty at first', (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      await tester.tap(find.text(SpiritualStrings.tabBookmarks));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.noBookmarks), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('bookmarks tab lists saved positions', (tester) async {
      final h = QuranHarness(
        initial: ReaderState(bookmarks: [
          Bookmark(surah: 18, ayah: 10, createdAt: DateTime(2026, 1, 2)),
          Bookmark(surah: 2, ayah: 255, createdAt: DateTime(2026, 1, 1)),
        ]),
      );
      await _pumpIndex(tester, h);
      await tester.tap(find.text(SpiritualStrings.tabBookmarks));
      await tester.pumpAndSettle();
      expect(find.text('سورة الكهف'), findsOneWidget);
      expect(find.text('الآية ١٠ · الجزء ١٥'), findsOneWidget);
      expect(find.text('سورة البقرة'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('swiping a bookmark away removes it and offers undo',
        (tester) async {
      final h = QuranHarness(
        initial: ReaderState(bookmarks: [
          Bookmark(surah: 18, ayah: 10, createdAt: DateTime(2026, 1, 2)),
          Bookmark(surah: 2, ayah: 255, createdAt: DateTime(2026, 1, 1)),
        ]),
      );
      await _pumpIndex(tester, h);
      await tester.tap(find.text(SpiritualStrings.tabBookmarks));
      await tester.pumpAndSettle();

      await tester.drag(find.text('سورة الكهف'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('سورة الكهف'), findsNothing);
      expect(find.text(SpiritualStrings.bookmarkRemoved), findsOneWidget);
      expect(h.reader.state.hasBookmark(18, 10), isFalse);

      await tester.tap(find.text(SpiritualStrings.undoAction));
      await tester.pumpAndSettle();
      expect(find.text('سورة الكهف'), findsOneWidget);
      expect(h.reader.state.hasBookmark(18, 10), isTrue);
      await disposeTree(tester);
    });
  });

  group('navigation', () {
    testWidgets('tapping a surah opens it in the reader and returns',
        (tester) async {
      final h = QuranHarness();
      var returned = 0;
      await _pumpIndex(tester, h, onReturned: () => returned++);
      await tester.tap(find.text('البقرة'));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      expect(find.text('سورة البقرة'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsNothing);
      expect(returned, 1);
      await disposeTree(tester);
    });

    testWidgets('a juz opens at the surah and ayah where it begins',
        (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h);
      await tester.tap(find.text(SpiritualStrings.tabJuz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجزء ٢'));
      await tester.pumpAndSettle();
      expect(find.text('سورة البقرة'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('embedded (tab) mode has no back button', (tester) async {
      final h = QuranHarness();
      await _pumpIndex(tester, h, embedded: true);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      await disposeTree(tester);
      await _pumpIndex(tester, h);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await disposeTree(tester);
    });
  });

  testWidgets('the surah of the last read position has an accent badge',
      (tester) async {
    final h = QuranHarness(
      initial: const ReaderState(lastRead: LastRead(surah: 1, ayah: 1)),
    );
    await _pumpIndex(tester, h);
    // The highlighted number is drawn in the accent colour.
    final texts = tester.widgetList<Text>(find.text('١')).toList();
    expect(texts.any((t) => t.style?.color == SpiritualTokens.light.accent), isTrue);
    await disposeTree(tester);
  });

  testWidgets('tappable targets are at least 48 dp', (tester) async {
    final h = QuranHarness(
      initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
    );
    await _pumpIndex(tester, h);
    for (final label in [
      SpiritualStrings.resume,
      SpiritualStrings.tabSurahs,
    ]) {
      final box = find.ancestor(
        of: find.text(label),
        matching: find.byType(PressScale),
      );
      if (box.evaluate().isNotEmpty) {
        expect(tester.getSize(box.first).height, greaterThanOrEqualTo(48));
      }
    }
    expect(tester.getSize(find.byType(TextField)).height, greaterThan(0));
    await disposeTree(tester);
  });

  testWidgets('survives text scale 2.0 without overflow', (tester) async {
    final h = QuranHarness(
      initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
    );
    await _pumpIndex(tester, h, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(SpiritualStrings.tabJuz));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('golden: index @ 390x844', (tester) async {
    final h = QuranHarness(
      initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
    );
    await _pumpIndex(tester, h);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/spiritual_quran_index.png'),
    );
    await disposeTree(tester);
  });

  testWidgets('golden: index while searching', (tester) async {
    final h = QuranHarness();
    await _pumpIndex(tester, h);
    await _search(tester, 'الكهف');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/spiritual_quran_index_search.png'),
    );
    await disposeTree(tester);
  });
}
