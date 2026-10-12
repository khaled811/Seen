/// Search normalisation for Arabic text (docs/03 §4): strips tashkeel and
/// Quranic annotation marks, unifies the alef forms (أ إ آ ٱ -> ا), ة -> ه and
/// ى -> ي, folds Arabic-Indic / Persian digits to Latin digits and lower-cases
/// Latin letters.
///
/// Only ever used to build a *search key*; displayed text is never altered.
///
/// Uthmani script writes some long vowels as a superscript (dagger) alef
/// instead of a letter ("ٱلْعَٰلَمِينَ" for "العالمين"). By default the dagger
/// alef is dropped; with [daggerAlefAsAlef] it becomes a real alef, so an
/// index can hold both spellings.
String normalizeArabic(String input, {bool daggerAlefAsAlef = false}) {
  final out = StringBuffer();
  for (final c in input.runes) {
    if (c == 0x0670 && daggerAlefAsAlef) {
      out.writeCharCode(0x0627);
      continue;
    }
    if (_isIgnorable(c)) continue;
    out.writeCharCode(_fold(c));
  }
  return out.toString();
}

/// Removes tashkeel and Quranic marks but keeps every letter as written
/// (used for *display* of surah names, which are metadata, not Quran text).
String stripDiacritics(String input) {
  final out = StringBuffer();
  for (final c in input.runes) {
    if (!_isIgnorable(c)) out.writeCharCode(c);
  }
  return out.toString();
}

/// Latin transliteration key: lower-case letters and digits only, so
/// "Al-Baqara", "al baqara" and "AlBaqara" all collapse to "albaqara".
String latinKey(String input) {
  final out = StringBuffer();
  for (final c in input.toLowerCase().runes) {
    if ((c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39)) {
      out.writeCharCode(c);
    }
  }
  return out.toString();
}

/// Replaces every Arabic-Indic / Persian digit with its ASCII digit.
String latinDigits(String input) {
  final out = StringBuffer();
  for (final c in input.runes) {
    out.writeCharCode(_digit(c) ?? c);
  }
  return out.toString();
}

bool _isIgnorable(int c) =>
    (c >= 0x0610 && c <= 0x061A) || // Quranic signs
    (c >= 0x064B && c <= 0x065F) || // harakat
    c == 0x0670 || // superscript alef
    c == 0x0640 || // tatweel
    (c >= 0x06D6 && c <= 0x06ED) || // small high/low marks, ayah sign
    (c >= 0x08D3 && c <= 0x08FF) || // extended Arabic marks
    c == 0xFEFF || // BOM
    (c >= 0x200B && c <= 0x200F); // zero-width / direction marks

int? _digit(int c) {
  if (c >= 0x0660 && c <= 0x0669) return 0x30 + (c - 0x0660);
  if (c >= 0x06F0 && c <= 0x06F9) return 0x30 + (c - 0x06F0);
  return null;
}

int _fold(int c) {
  switch (c) {
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0622: // آ
    case 0x0671: // ٱ
      return 0x0627; // ا
    case 0x0629: // ة
      return 0x0647; // ه
    case 0x0649: // ى
      return 0x064A; // ي
  }
  final d = _digit(c);
  if (d != null) return d;
  if (c >= 0x41 && c <= 0x5A) return c + 32; // A-Z -> a-z
  return c;
}
