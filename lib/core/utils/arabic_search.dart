/// Arabic-aware search (design/gaps SPEC §10.2): diacritics and tatweel are ignored and the
/// letters people type interchangeably are treated as one (أ إ آ ٱ = ا, ة = ه, ى = ي), so a search
/// for «الحجوزات» finds «الحجوزات» typed with or without marks.
abstract final class ArabicSearch {
  static final _ignored = RegExp('[ً-ٰٟـ]');

  static String _fold(String ch) => switch (ch) {
        'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
        'ة' => 'ه',
        'ى' => 'ي',
        _ => ch.toLowerCase(),
      };

  /// [input] folded for comparison.
  static String normalize(String input) {
    final out = StringBuffer();
    for (final ch in input.split('')) {
      if (!_ignored.hasMatch(ch)) {
        out.write(_fold(ch));
      }
    }
    return out.toString().trim();
  }

  /// Does [query] occur in [text] once both are folded? An empty query matches everything.
  static bool matches(String query, String text) {
    final q = normalize(query);
    return q.isEmpty || normalize(text).contains(q);
  }

  /// Where [query] occurs in the ORIGINAL [text] (for highlighting), or null. Folding removes
  /// characters, so the range found in the folded text is mapped back to the original one.
  static ({int start, int end})? range(String query, String text) {
    final q = normalize(query);
    if (q.isEmpty) {
      return null;
    }
    final folded = StringBuffer();
    final origin = <int>[]; // folded index -> index in [text]
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_ignored.hasMatch(ch)) {
        continue;
      }
      folded.write(_fold(ch));
      origin.add(i);
    }
    final at = folded.toString().indexOf(q);
    if (at < 0) {
      return null;
    }
    var end = origin[at + q.length - 1] + 1;
    // Keep the marks that belong to the last matched letter inside the highlight.
    while (end < text.length && _ignored.hasMatch(text[end])) {
      end++;
    }
    return (start: origin[at], end: end);
  }
}
