import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/data/repositories/json_quran_repository.dart';
import 'package:seen_booking/features/spiritual/domain/entities/quran.dart';
import 'package:seen_booking/features/spiritual/domain/entities/quran_data.dart';
import 'package:seen_booking/features/spiritual/domain/utils/arabic_normalizer.dart';

/// Integrity checks on the real bundled `assets/data/quran.json`, so a
/// corrupted or truncated dataset can never ship silently.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranData quran;

  setUpAll(() async {
    final result = await JsonQuranRepository(useIsolate: false).load();
    quran = result.getOrElse((f) => throw StateError(f.message));
  });

  test('has 114 surahs and 6236 ayahs', () {
    expect(quran.surahs, hasLength(114));
    expect(quran.ayahCount, 6236);
    for (var i = 0; i < 114; i++) {
      expect(quran.surahs[i].number, i + 1);
    }
  });

  test('every surah\'s declared count matches its ayahs, numbered 1..n', () {
    for (final s in quran.surahs) {
      final ayahs = quran.ayahsOf(s.number);
      expect(ayahs.length, s.ayahCount, reason: 'surah ${s.number}');
      for (var i = 0; i < ayahs.length; i++) {
        expect(ayahs[i].number, i + 1, reason: 'surah ${s.number}');
        expect(ayahs[i].surah, s.number);
        expect(ayahs[i].text.trim(), isNotEmpty);
      }
    }
  });

  test('well-known ayah counts', () {
    int count(int n) => quran.surah(n).ayahCount;
    expect(count(1), 7);
    expect(count(2), 286);
    expect(count(9), 129);
    expect(count(18), 110);
    expect(count(36), 83);
    expect(count(67), 30);
    expect(count(108), 3);
    expect(count(114), 6);
  });

  test('revelation type of well-known surahs', () {
    expect(quran.surah(2).revelation, Revelation.madani);
    expect(quran.surah(18).revelation, Revelation.makki);
    expect(quran.surah(114).revelation, Revelation.makki);
    expect(quran.surah(110).revelation, Revelation.madani);
  });

  test('30 juz and 604 pages, starting where the mushaf says', () {
    expect(quran.juzs, hasLength(30));
    expect(quran.juzs.first.firstSurah, 1);
    expect(quran.juzs[1].firstSurah, 2); // juz 2 starts at Al-Baqarah 142
    expect(quran.juzs[1].firstAyah, 142);
    expect(quran.juzs[14].firstSurah, 17); // juz 15 starts at Al-Isra 1
    expect(quran.juzs[14].firstAyah, 1);
    expect(quran.juzs[14].startPage, 282);
    expect(quran.juzs[15].firstSurah, 18); // juz 16 starts at Al-Kahf 75
    expect(quran.juzs[15].firstAyah, 75);
    expect(quran.ayah(18, 1)!.juz, 15, reason: 'Al-Kahf opens inside juz 15');
    expect(quran.pages, hasLength(604));
    expect(quran.pages.first.number, 1);
    expect(quran.pages.last.number, 604);
  });

  test('pages and juz never decrease through the mushaf', () {
    var page = 0;
    var juz = 0;
    for (final s in quran.surahs) {
      for (final a in quran.ayahsOf(s.number)) {
        expect(a.page, greaterThanOrEqualTo(page));
        expect(a.juz, greaterThanOrEqualTo(juz));
        page = a.page;
        juz = a.juz;
      }
    }
    expect(page, 604);
    expect(juz, 30);
  });

  test('surah start pages match the Madinah mushaf', () {
    expect(quran.surah(1).startPage, 1);
    expect(quran.surah(2).startPage, 2);
    expect(quran.surah(18).startPage, 293);
    expect(quran.surah(36).startPage, 440);
    expect(quran.surah(67).startPage, 562);
    expect(quran.surah(114).startPage, 604);
  });

  test('display names are plain Arabic without the "سورة" prefix', () {
    expect(quran.surah(1).nameAr, 'الفاتحة');
    expect(quran.surah(2).nameAr, 'البقرة');
    expect(quran.surah(3).nameAr, 'آل عمران');
    expect(quran.surah(18).nameAr, 'الكهف');
    expect(quran.surah(114).nameAr, 'الناس');
    for (final s in quran.surahs) {
      expect(s.nameAr.startsWith('سورة'), isFalse, reason: s.nameAr);
      expect(RegExp('[ً-ٟ]').hasMatch(s.nameAr), isFalse);
    }
  });

  group('basmala handling', () {
    // Compared by search key so the test never retypes Quranic spelling.
    String key(String t) => normalizeArabic(t);
    const basmalaKey = 'بسم الله الرحمن الرحيم';

    test('Al-Fatihah keeps its basmala as ayah 1 (without a BOM)', () {
      final first = quran.ayah(1, 1)!.text;
      expect(key(first), basmalaKey);
      expect(first.contains('﻿'), isFalse);
    });

    test('no other surah\'s first ayah still carries the basmala header', () {
      for (final s in quran.surahs.where((s) => s.number != 1)) {
        final first = quran.ayah(s.number, 1)!.text;
        expect(key(first).startsWith(basmalaKey), isFalse,
            reason: 'surah ${s.number}');
        expect(first.trim(), isNotEmpty);
      }
    });

    test('the first real words are intact', () {
      expect(key(quran.ayah(2, 1)!.text), 'الم');
      expect(key(quran.ayah(18, 1)!.text).startsWith('الحمد لله'), isTrue);
      expect(key(quran.ayah(9, 1)!.text).startsWith('براءه'), isTrue);
    });

    test('no ayah contains a BOM', () {
      for (final s in quran.surahs) {
        for (final a in quran.ayahsOf(s.number)) {
          expect(a.text.contains('﻿'), isFalse);
        }
      }
    });
  });

  test('sajda ayahs exist (15 in the Madinah mushaf)', () {
    final n = quran.surahs
        .expand((s) => quran.ayahsOf(s.number))
        .where((a) => a.sajda)
        .length;
    expect(n, 15);
  });

  test('pages tile the mushaf: each starts right after the previous ends', () {
    for (var i = 1; i < quran.pages.length; i++) {
      final prev = quran.pages[i - 1];
      final cur = quran.pages[i];
      final lastOfPrev = quran.ayah(prev.lastSurah, prev.lastAyah)!;
      final firstOfCur = quran.ayah(cur.firstSurah, cur.firstAyah)!;
      expect(firstOfCur.page, cur.number);
      expect(lastOfPrev.page, prev.number);
      final nextAfterPrev = lastOfPrev.number < quran.surah(lastOfPrev.surah).ayahCount
          ? quran.ayah(lastOfPrev.surah, lastOfPrev.number + 1)!
          : quran.ayah(lastOfPrev.surah + 1, 1)!;
      expect(nextAfterPrev.surah, firstOfCur.surah, reason: 'page ${cur.number}');
      expect(nextAfterPrev.number, firstOfCur.number, reason: 'page ${cur.number}');
    }
  });

  test('loading twice returns the cached data', () async {
    final repo = JsonQuranRepository(useIsolate: false);
    final a = (await repo.load()).getOrElse((_) => throw 'x');
    final b = (await repo.load()).getOrElse((_) => throw 'x');
    expect(identical(a, b), isTrue);
  });
}
