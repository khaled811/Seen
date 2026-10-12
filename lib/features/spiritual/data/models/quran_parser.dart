import 'dart:convert';

import '../../domain/entities/juz.dart';
import '../../domain/entities/mushaf_page.dart';
import '../../domain/entities/quran.dart';
import '../../domain/entities/quran_data.dart';
import '../../domain/utils/arabic_normalizer.dart';

/// Parses `assets/data/quran.json` (built by `tool/prepare_quran.py`).
/// Top-level and free of Flutter types so it can run in a background isolate.
///
/// Throws [FormatException] when the structure is not what the tool emits.
///
/// Display-level adjustments to the ayah text (nothing else is touched):
///  * a leading U+FEFF byte-order mark is dropped (it is not part of the text);
///  * the dataset prefixes ayah 1 of every surah except Al-Fatihah and
///    At-Tawbah with the basmala (spelled slightly differently in a few
///    surahs, e.g. an extra shadda in 95 and 97); the reader shows the basmala
///    as a header, so those first four words are removed. They are matched by
///    their normalised form, and if they are not the basmala the text is left
///    untouched.
QuranData parseQuranJson(String source) {
  final root = jsonDecode(source);
  if (root is! Map<String, Object?>) {
    throw const FormatException('quran.json: root is not an object');
  }
  final rawSurahs = root['surahs'];
  if (rawSurahs is! List || rawSurahs.length != 114) {
    throw const FormatException('quran.json: expected 114 surahs');
  }

  String clean(String t) => t.replaceAll('﻿', '');
  final basmalaKey = normalizeArabic(clean(
    ((rawSurahs.first as Map)['ayahs'] as List).first['text'] as String,
  ));

  final surahs = <Surah>[];
  final bySurah = <List<Ayah>>[];
  for (final raw in rawSurahs.cast<Map<String, Object?>>()) {
    final number = raw['number']! as int;
    final rawAyahs = (raw['ayahs']! as List).cast<Map<String, Object?>>();
    final ayahs = <Ayah>[];
    for (final a in rawAyahs) {
      final n = a['n']! as int;
      var text = clean(a['text']! as String);
      if (n == 1 && number != 1 && number != 9) {
        text = _withoutBasmalaHeader(text, basmalaKey);
      }
      ayahs.add(Ayah(
        surah: number,
        number: n,
        text: text,
        page: a['page']! as int,
        juz: a['juz']! as int,
        hizb: a['hizbQuarter']! as int,
        sajda: a['sajda'] == true,
      ));
    }
    surahs.add(Surah(
      number: number,
      nameAr: _displayName(raw['name']! as String),
      transliteration: raw['englishName']! as String,
      revelation: raw['revelationType'] == 'Meccan'
          ? Revelation.makki
          : Revelation.madani,
      ayahCount: ayahs.length,
      startPage: ayahs.first.page,
    ));
    bySurah.add(ayahs);
  }

  return QuranData(
    surahs: surahs,
    juzs: _juzs(bySurah),
    pages: _pages(bySurah),
    ayahsBySurah: bySurah,
  );
}

/// Drops the leading four-word basmala from [text] when present.
String _withoutBasmalaHeader(String text, String basmalaKey) {
  final words = text.split(' ');
  if (words.length <= 4) return text;
  if (normalizeArabic(words.take(4).join(' ')) != basmalaKey) return text;
  return words.skip(4).join(' ');
}

/// "سُورَةُ ٱلْفَاتِحَةِ" -> "الفاتحة".
String _displayName(String raw) {
  // Recompose a decomposed madda (ا + U+0653) before stripping marks.
  var name = stripDiacritics(raw.replaceAll('آ', 'آ'))
      .replaceAll('ٱ', 'ا')
      .trim();
  if (name.startsWith('سورة ')) name = name.substring(5);
  return name;
}

List<Juz> _juzs(List<List<Ayah>> bySurah) {
  final out = <Juz>[];
  var last = 0;
  for (final ayahs in bySurah) {
    for (final a in ayahs) {
      if (a.juz != last) {
        out.add(Juz(
          number: a.juz,
          firstSurah: a.surah,
          firstAyah: a.number,
          startPage: a.page,
        ));
        last = a.juz;
      }
    }
  }
  return out;
}

List<MushafPage> _pages(List<List<Ayah>> bySurah) {
  final first = <int, Ayah>{};
  final lastOf = <int, Ayah>{};
  for (final ayahs in bySurah) {
    for (final a in ayahs) {
      first.putIfAbsent(a.page, () => a);
      lastOf[a.page] = a;
    }
  }
  return [
    for (final p in (first.keys.toList()..sort()))
      MushafPage(
        number: p,
        juz: first[p]!.juz,
        firstSurah: first[p]!.surah,
        firstAyah: first[p]!.number,
        lastSurah: lastOf[p]!.surah,
        lastAyah: lastOf[p]!.number,
      ),
  ];
}
