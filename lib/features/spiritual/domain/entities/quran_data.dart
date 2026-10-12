import '../utils/arabic_normalizer.dart';
import 'ayah_match.dart';
import 'juz.dart';
import 'mushaf_page.dart';
import 'quran.dart';

/// The whole bundled Quran, parsed once and held in memory (~1.7 MB of text):
/// surah metadata, the 30 juz, the 604 pages and every ayah.
///
/// Search keys are built lazily on the first full-text search.
class QuranData {
  QuranData({
    required this.surahs,
    required this.juzs,
    required this.pages,
    required List<List<Ayah>> ayahsBySurah,
  }) : _ayahsBySurah = ayahsBySurah;

  final List<Surah> surahs;
  final List<Juz> juzs;
  final List<MushafPage> pages;
  final List<List<Ayah>> _ayahsBySurah;

  List<String>? _keys; // normalised text, parallel to _flat
  List<String>? _keysWithAlef; // same, dagger alef spelled as a letter
  List<Ayah>? _flat;

  /// Surah by number (1..114).
  Surah surah(int number) => surahs[number - 1];

  /// Ayahs of [surahNumber] in order (index 0 = ayah 1).
  List<Ayah> ayahsOf(int surahNumber) => _ayahsBySurah[surahNumber - 1];

  Ayah? ayah(int surahNumber, int ayahNumber) {
    if (surahNumber < 1 || surahNumber > surahs.length) return null;
    final list = _ayahsBySurah[surahNumber - 1];
    if (ayahNumber < 1 || ayahNumber > list.length) return null;
    return list[ayahNumber - 1];
  }

  int get ayahCount => _ayahsBySurah.fold(0, (n, l) => n + l.length);

  /// The ayahs printed on mushaf [page] (1..604), in reading order.
  List<Ayah> ayahsOnPage(int page) {
    final p = pages[page - 1];
    final out = <Ayah>[];
    for (var s = p.firstSurah; s <= p.lastSurah; s++) {
      final list = _ayahsBySurah[s - 1];
      final from = s == p.firstSurah ? p.firstAyah : 1;
      final to = s == p.lastSurah ? p.lastAyah : list.length;
      out.addAll(list.sublist(from - 1, to));
    }
    return out;
  }

  /// Juz containing [surahNumber]:[ayahNumber].
  int juzOf(int surahNumber, int ayahNumber) =>
      ayah(surahNumber, ayahNumber)?.juz ?? 1;

  /// Full-text search over the normalised ayah text. Tashkeel, alef/ya/ta
  /// marbuta variants and digits are ignored on both sides, and Uthmani dagger
  /// alefs match whether or not the query spells the alef. Results come in
  /// mushaf order, at most [limit].
  List<AyahMatch> search(String query, {int limit = 100}) {
    final q = normalizeArabic(query).trim();
    if (q.isEmpty) return const [];
    final flat = _flat ??= [for (final l in _ayahsBySurah) ...l];
    final keys = _keys ??= [for (final a in flat) normalizeArabic(a.text)];
    final withAlef = _keysWithAlef ??= [
      for (final a in flat) normalizeArabic(a.text, daggerAlefAsAlef: true),
    ];
    final out = <AyahMatch>[];
    for (var i = 0; i < keys.length && out.length < limit; i++) {
      if (keys[i].contains(q) || withAlef[i].contains(q)) {
        out.add(AyahMatch(surah: surah(flat[i].surah), ayah: flat[i]));
      }
    }
    return out;
  }
}
