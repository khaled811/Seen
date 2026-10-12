import '../entities/juz.dart';
import '../entities/quran.dart';
import 'arabic_normalizer.dart';

/// Matches a surah by Arabic name (any tashkeel/hamza spelling), by
/// transliteration (case-insensitive, punctuation ignored) or by number in
/// Arabic or Latin digits. An empty query matches everything.
bool surahMatches(Surah surah, String rawQuery) {
  final q = normalizeArabic(rawQuery).trim();
  if (q.isEmpty) return true;
  if (q == surah.number.toString()) return true;
  if (normalizeArabic(surah.nameAr).contains(q)) return true;
  final latin = latinKey(rawQuery);
  return latin.isNotEmpty &&
      latinKey(surah.transliteration).contains(latin);
}

/// Matches a juz by its number, by the name of the surah it starts in, or by
/// the words "الجزء N".
bool juzMatches(Juz juz, Surah startSurah, String rawQuery) {
  final q = normalizeArabic(rawQuery).trim();
  if (q.isEmpty) return true;
  if (q == juz.number.toString()) return true;
  if (normalizeArabic(startSurah.nameAr).contains(q)) return true;
  return normalizeArabic('الجزء ${juz.number}').contains(q);
}
