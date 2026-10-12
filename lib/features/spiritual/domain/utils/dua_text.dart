import '../entities/dua.dart';
import '../entities/dua_filter.dart';
import 'arabic_normalizer.dart';

/// The text shared or copied for [dua]: the dua, then its source on its own
/// line, so a quoted dua never travels without where it comes from.
String duaShareText(Dua dua) => '${dua.text}\n— ${dua.source}';

/// [duas] narrowed by chip and by search [query]. The search ignores tashkeel
/// and alef/ya/ta-marbuta spelling variants and looks in the title, the text,
/// the source and the usage note. Order is preserved.
List<Dua> filterDuas(
  List<Dua> duas, {
  required DuaFilter filter,
  required Set<String> favorites,
  String query = '',
}) {
  final q = normalizeArabic(query).trim();
  return [
    for (final d in duas)
      if (filter.matches(d, favorites) && (q.isEmpty || _matches(d, q))) d,
  ];
}

bool _matches(Dua d, String q) =>
    normalizeArabic(d.title).contains(q) ||
    normalizeArabic(d.text).contains(q) ||
    normalizeArabic(d.source).contains(q) ||
    (d.note != null && normalizeArabic(d.note!).contains(q));
