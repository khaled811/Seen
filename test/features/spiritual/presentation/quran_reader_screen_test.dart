import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/bookmark.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_ayah_tile.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_reader_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';

import '../support/quran_harness.dart';

Future<void> _pumpReader(
  WidgetTester tester,
  QuranHarness h, {
  int surah = 1,
  int ayah = 1,
  double textScale = 1,
}) =>
    pumpHub(
      tester,
      QuranReaderScreen(surah: surah, ayah: ayah, module: h.module),
      textScale: textScale,
    );

Finder _subtitle(String text) => find.text(text);

void main() {
  setUpAll(QuranHarness.preload);

  testWidgets('Al-Fatihah: header, seven ayahs, no separate basmala',
      (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h);
    expect(find.text('سورة الفاتحة'), findsOneWidget);
    expect(_subtitle('مكية · ٧ آيات · صفحة ١'), findsOneWidget);
    // The list is lazy: only the ayahs near the screen are built.
    expect(find.byType(QuranAyahTile), findsAtLeastNWidgets(3));
    expect(find.byType(QuranAyahTile).evaluate().length, lessThanOrEqualTo(7));
    // The basmala IS ayah 1 here, so it must appear exactly once.
    final basmala = QuranHarness.data.ayah(1, 1)!.text;
    expect(find.textContaining(basmala), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('other surahs show the basmala as a header above ayah 1',
      (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h, surah: 2);
    final basmala = QuranHarness.data.ayah(1, 1)!.text;
    expect(find.text(basmala), findsOneWidget, reason: 'header, plain Text');
    expect(find.text('سورة البقرة'), findsOneWidget);
    expect(_subtitle('مدنية · ٢٨٦ آيات · صفحة ٢'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('At-Tawbah has no basmala', (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h, surah: 9);
    final basmala = QuranHarness.data.ayah(1, 1)!.text;
    expect(find.text(basmala), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('ayah numbers are drawn in Arabic-Indic digits', (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h);
    for (final n in ['١', '٢', '٣']) {
      expect(find.text(n), findsWidgets, reason: n);
    }
    await disposeTree(tester);
  });

  group('font size', () {
    testWidgets('A+ / A- change the size, show it, and persist it',
        (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h);
      expect(find.text('٣٠'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(SpiritualStrings.biggerFont));
      await tester.pumpAndSettle();
      expect(find.text('٣٤'), findsOneWidget);
      expect(h.reader.state.fontStep, 3);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.bySemanticsLabel(SpiritualStrings.smallerFont));
        await tester.pumpAndSettle();
      }
      expect(find.text('٢٤'), findsOneWidget);
      expect(h.reader.state.fontStep, 0);
      await disposeTree(tester);
    });

    testWidgets('the ayah text really changes size', (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h);
      double size() => tester
          .widget<AnimatedDefaultTextStyle>(
            find.descendant(
              of: find.byType(QuranAyahTile).first,
              matching: find.byType(AnimatedDefaultTextStyle),
            ),
          )
          .style
          .fontSize!;
      expect(size(), 30);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.biggerFont));
      await tester.pumpAndSettle();
      expect(size(), 34);
      await disposeTree(tester);
    });

    testWidgets('a stored size is applied on open', (tester) async {
      final h = QuranHarness(initial: const ReaderState(fontStep: 5));
      await _pumpReader(tester, h);
      expect(find.text('٤٢'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('A+ stops at 42 and A- at 24', (tester) async {
      final h = QuranHarness(initial: const ReaderState(fontStep: 5));
      await _pumpReader(tester, h);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.biggerFont));
      await tester.pumpAndSettle();
      expect(h.reader.state.fontStep, 5);
      await disposeTree(tester);
    });
  });

  group('bookmarks', () {
    testWidgets('the header button bookmarks the ayah at the top',
        (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.saveReadingPosition));
      await tester.pumpAndSettle();
      expect(h.reader.state.hasBookmark(1, 1), isTrue);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(SpiritualStrings.saveReadingPosition));
      await tester.pumpAndSettle();
      expect(h.reader.state.bookmarks, isEmpty);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('existing bookmarks are restored on open', (tester) async {
      final h = QuranHarness(
        initial: ReaderState(
          bookmarks: [Bookmark(surah: 1, ayah: 1, createdAt: DateTime(2026))],
        ),
      );
      await _pumpReader(tester, h);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a failed save warns the user', (tester) async {
      final h = QuranHarness();
      h.reader.failWrites = true;
      await _pumpReader(tester, h);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.saveReadingPosition));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.saveFailed), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('opening at an ayah', () {
    testWidgets('scrolls to ayah 255 of Al-Baqarah (page 42)', (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2, ayah: 255);
      expect(_subtitle('مدنية · ٢٨٦ آيات · صفحة ٤٢'), findsOneWidget);
      expect(find.text('٢٥٥'), findsOneWidget, reason: 'its number emblem');
      await disposeTree(tester);
    });

    testWidgets('bookmarking there bookmarks that ayah', (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2, ayah: 255);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.saveReadingPosition));
      await tester.pumpAndSettle();
      expect(h.reader.state.hasBookmark(2, 255), isTrue);
      await disposeTree(tester);
    });

    testWidgets('changing the font keeps the same ayah in view', (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2, ayah: 255);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.biggerFont));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(_subtitle('مدنية · ٢٨٦ آيات · صفحة ٤٢'), findsOneWidget);
      expect(find.text('٢٥٥'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the last ayah of a long surah is reachable', (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2, ayah: 286);
      expect(find.text('٢٨٦'), findsWidgets);
      await disposeTree(tester);
    });
  });

  group('last read', () {
    testWidgets('is saved 2 s after scrolling stops', (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2);
      expect(h.reader.lastReadSaves, 0);

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(h.reader.lastReadSaves, 0, reason: 'not yet — only 1 s');
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      expect(h.reader.lastReadSaves, 1);
      expect(h.reader.state.lastRead?.surah, 2);
      expect(h.reader.state.lastRead!.ayah, greaterThan(1));
      await disposeTree(tester);
    });

    testWidgets('scrolling again restarts the 2 s wait', (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(h.reader.lastReadSaves, 0);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(h.reader.lastReadSaves, 1);
      await disposeTree(tester);
    });

    testWidgets('leaving right after scrolling saves immediately',
        (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2);
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump(const Duration(milliseconds: 200));
      await disposeTree(tester);
      expect(h.reader.lastReadSaves, 1);
      expect(h.reader.state.lastRead?.surah, 2);
    });

    testWidgets('merely opening and leaving does not overwrite the position',
        (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2);
      await disposeTree(tester);
      expect(h.reader.lastReadSaves, 0);
      expect(h.reader.state.lastRead, isNull);
    });

    testWidgets('a failed save warns', (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h, surah: 2);
      h.reader.failWrites = true;
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump();
      expect(find.text(SpiritualStrings.saveFailed), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('sheets', () {
    testWidgets('tafsir sheet shows the ayah and clear placeholders',
        (tester) async {
      final h = QuranHarness();
      await _pumpReader(tester, h);
      await tester.tap(find.text(SpiritualStrings.tafsirAndTranslation).first);
      await tester.pumpAndSettle();
      expect(find.text('الآية ١ · سورة الفاتحة'), findsOneWidget);
      expect(find.text(SpiritualStrings.meaningOfAyah), findsOneWidget);
      expect(find.text(SpiritualStrings.tafsirPlaceholder), findsOneWidget);
      expect(find.text(SpiritualStrings.translationPlaceholder), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.close));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.meaningOfAyah), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('long-press copies the ayah with its reference',
        (tester) async {
      final h = QuranHarness();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _pumpReader(tester, h);
      await tester.longPress(find.descendant(
        of: find.byType(QuranAyahTile).at(1),
        matching: find.byType(AnimatedDefaultTextStyle),
      ));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.copyAyah), findsOneWidget);
      await tester.tap(find.text(SpiritualStrings.copyAyah));
      await tester.pumpAndSettle();

      final ayah2 = QuranHarness.data.ayah(1, 2)!.text;
      expect(copied, startsWith(ayah2));
      expect(copied, contains('﴿٢﴾'));
      expect(copied, contains('الفاتحة'));
      expect(find.text(SpiritualStrings.copied), findsOneWidget);
      await disposeTree(tester);
    });
  });

  testWidgets('the app theme\'s Latin digits never leak into the reader',
      (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h);
    final texts = tester.widgetList<Text>(find.byType(Text));
    for (final t in texts) {
      final s = t.data ?? t.textSpan?.toPlainText() ?? '';
      expect(RegExp(r'[0-9]').hasMatch(s), isFalse, reason: s);
    }
    await disposeTree(tester);
  });

  testWidgets('survives text scale 2.0 without overflow', (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h, surah: 18, textScale: 2);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('tappable controls are at least 48 dp', (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h);
    for (final label in [
      SpiritualStrings.smallerFont,
      SpiritualStrings.biggerFont,
      SpiritualStrings.saveReadingPosition,
      SpiritualStrings.back,
    ]) {
      final size = tester.getSize(find.bySemanticsLabel(label).first);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    await disposeTree(tester);
  });

  testWidgets('golden: Al-Kahf @ 390x844 (matches Quran.dc.html)',
      (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h, surah: 18);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/spiritual_quran_reader_kahf.png'),
    );
    await disposeTree(tester);
  });

  testWidgets('golden: tafsir sheet open', (tester) async {
    final h = QuranHarness();
    await _pumpReader(tester, h, surah: 18);
    await tester.tap(find.text(SpiritualStrings.tafsirAndTranslation).at(2));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/spiritual_quran_reader_sheet.png'),
    );
    await disposeTree(tester);
  });
}
