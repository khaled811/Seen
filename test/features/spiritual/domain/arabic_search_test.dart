import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/data/repositories/json_quran_repository.dart';
import 'package:seen_booking/features/spiritual/domain/entities/quran_data.dart';
import 'package:seen_booking/features/spiritual/domain/utils/arabic_normalizer.dart';
import 'package:seen_booking/features/spiritual/domain/utils/quran_filters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeArabic', () {
    test('strips tashkeel and Quranic marks', () {
      expect(normalizeArabic('بِسْمِ ٱللَّهِ'), 'بسم الله');
      expect(normalizeArabic('الْحَمْدُ لِلَّهِ'), 'الحمد لله');
      expect(normalizeArabic('رَبَّنَا آتِنَا'), 'ربنا اتنا');
    });

    test('unifies alef/hamza forms, ta marbuta and alef maqsura', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إبراهيم'), normalizeArabic('ابراهيم'));
      expect(normalizeArabic('آل عمران'), normalizeArabic('ال عمران'));
      expect(normalizeArabic('ٱلرحمن'), normalizeArabic('الرحمن'));
      expect(normalizeArabic('البقرة'), normalizeArabic('البقره'));
      expect(normalizeArabic('موسى'), normalizeArabic('موسي'));
    });

    test('folds Arabic-Indic and Persian digits, lower-cases Latin', () {
      expect(normalizeArabic('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeArabic('۱۲۳'), '123');
      expect(normalizeArabic('Al-Baqarah'), 'al-baqarah');
    });

    test('removes tatweel, BOM and zero-width marks', () {
      expect(normalizeArabic('الـــكهف'), 'الكهف');
      expect(normalizeArabic('﻿الكهف'), 'الكهف');
      expect(normalizeArabic('ال‌كهف'), 'الكهف');
    });
  });

  test('latinKey ignores case and punctuation', () {
    expect(latinKey("Al-Baqara"), 'albaqara');
    expect(latinKey("al baqara"), 'albaqara');
    expect(latinKey("Al 'Imran"), 'alimran');
  });

  group('surah / juz filters over the real dataset', () {
    late QuranData quran;

    setUpAll(() async {
      quran = (await JsonQuranRepository(useIsolate: false).load())
          .getOrElse((_) => throw 'x');
    });

    List<int> surahs(String q) => [
          for (final s in quran.surahs)
            if (surahMatches(s, q)) s.number
        ];

    test('empty query matches all 114', () {
      expect(surahs(''), hasLength(114));
      expect(surahs('   '), hasLength(114));
    });

    test('by Arabic name, with or without tashkeel / hamza variants', () {
      expect(surahs('الكهف'), [18]);
      expect(surahs('الْكَهْف'), [18]);
      expect(surahs('البقره'), [2]);
      expect(surahs('البقرة'), [2]);
      expect(surahs('ابراهيم'), [14]);
      expect(surahs('إبراهيم'), [14]);
      expect(surahs('عمران'), [3]);
      expect(surahs('آل عمران'), [3]);
      expect(surahs('ال عمران'), [3]);
    });

    test('by transliteration, case-insensitive, punctuation-free', () {
      expect(surahs('KAHF'), contains(18));
      expect(surahs('kahf'), contains(18));
      expect(surahs('al-kahf'), contains(18));
      expect(surahs('baqara'), contains(2));
    });

    test('by number in Latin or Arabic digits', () {
      expect(surahs('18'), [18]);
      expect(surahs('١٨'), [18]);
      expect(surahs('114'), [114]);
      expect(surahs('٢'), [2]);
    });

    test('nonsense matches nothing', () {
      expect(surahs('zzzzqqq'), isEmpty);
      expect(surahs('ضضضضض'), isEmpty);
    });

    test('juz by number, by starting surah and by "الجزء N"', () {
      List<int> juz(String q) => [
            for (final j in quran.juzs)
              if (juzMatches(j, quran.surah(j.firstSurah), q)) j.number
          ];
      expect(juz(''), hasLength(30));
      expect(juz('15'), [15]);
      expect(juz('١٥'), [15]);
      expect(juz('الكهف'), [16], reason: 'juz 16 starts inside Al-Kahf');
      expect(juz('الاسراء'), [15]);
      expect(juz('الجزء ٢'), contains(2));
    });
  });

  group('full-text ayah search', () {
    late QuranData quran;

    setUpAll(() async {
      quran = (await JsonQuranRepository(useIsolate: false).load())
          .getOrElse((_) => throw 'x');
    });

    test('empty query yields nothing', () {
      expect(quran.search(''), isEmpty);
      expect(quran.search('   '), isEmpty);
    });

    test('finds a phrase regardless of tashkeel or hamza spelling', () {
      final plain = quran.search('الحمد لله رب العالمين');
      expect(plain, isNotEmpty);
      final marks = quran.search('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ');
      expect(marks.map((m) => '${m.surah.number}:${m.ayah.number}'),
          plain.map((m) => '${m.surah.number}:${m.ayah.number}'));
      expect(plain.first.ayah.number, 2);
      expect(plain.first.surah.number, 1);
      expect(plain.first.ayah.number, 2);
    });

    test('results come in mushaf order and are capped at the limit', () {
      final r = quran.search('الله', limit: 7);
      expect(r, hasLength(7));
      var last = 0;
      for (final m in r) {
        final g = m.surah.number * 1000 + m.ayah.number;
        expect(g, greaterThan(last));
        last = g;
      }
    });

    test('Uthmani dagger-alef words match whether or not the alef is typed',
        () {
      // "هَٰذَا" is written with a dagger alef; people type "هذا".
      expect(quran.search('هذا'), isNotEmpty);
      expect(quran.search('هاذا'), isNotEmpty);
      // "ٱلْعَٰلَمِينَ" -> typed "العالمين" and "العلمين" both find it.
      expect(quran.search('رب العالمين').first.ayah.number, 2);
      expect(quran.search('رب العلمين').first.ayah.number, 2);
    });

    test('a query with no match returns an empty list', () {
      expect(quran.search('zzzz'), isEmpty);
    });
  });
}
