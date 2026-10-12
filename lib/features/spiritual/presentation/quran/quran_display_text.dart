import '../theme/spiritual_tokens.dart';

/// Code points the bundled KFGQPC Uthmanic Script HAFS font (v0.09) cannot
/// draw: it maps each of them to a large dashed-circle placeholder glyph.
///
///  * U+06DF small high rounded zero (silent-letter marker)
///  * U+06E3 small low seen
///  * U+06EA / U+06EB empty-centre low / high stop
///  * U+06ED small low meem (tanween idgham/iqlab marker)
///
/// Found by diffing the dataset against the font's cmap and glyph outlines
/// (see the M4 notes). Together they occur ~8,800 times in the text.
const unsupportedByQuranFont = <int>{0x06DF, 0x06E3, 0x06EA, 0x06EB, 0x06ED};

/// The Quran text as it should be *drawn* with the bundled font.
///
/// This is a stop-gap, isolated here on purpose: the stored dataset and the
/// copy-to-clipboard text are never altered. With this font the five marks
/// above are left out of the drawing so the page is not covered in
/// placeholder circles; no letter, vowel or other mark is touched, so the text
/// still reads correctly, but those tajweed markers are not shown.
///
/// Remove the need for it by bundling a font with a complete mark set (a newer
/// KFGQPC release or Amiri Quran) and setting
/// [SpiritualFonts.quranFontHasFullMarkSet] to true.
String quranDisplayText(String text) {
  if (SpiritualFonts.quranFontHasFullMarkSet) return text;
  var needsChange = false;
  for (final c in text.runes) {
    if (unsupportedByQuranFont.contains(c)) {
      needsChange = true;
      break;
    }
  }
  if (!needsChange) return text;
  final out = StringBuffer();
  for (final c in text.runes) {
    if (!unsupportedByQuranFont.contains(c)) out.writeCharCode(c);
  }
  return out.toString();
}
