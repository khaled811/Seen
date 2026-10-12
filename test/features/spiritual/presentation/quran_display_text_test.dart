import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_display_text.dart';
import 'package:seen_booking/features/spiritual/presentation/theme/spiritual_tokens.dart';

import '../support/quran_harness.dart';

/// Every code point the dataset uses that the bundled KFGQPC v0.09 font can
/// draw (verified against the font's cmap and glyph outlines). If the dataset
/// ever contains a code point outside this set, the font must be re-checked.
const _drawableByFont = <int>{
  0x0020, 0x0621, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627, 0x0628, 0x0629, //
  0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x062F, 0x0630, 0x0631, 0x0632,
  0x0633, 0x0634, 0x0635, 0x0636, 0x0637, 0x0638, 0x0639, 0x063A, 0x0640,
  0x0641, 0x0642, 0x0643, 0x0644, 0x0645, 0x0646, 0x0647, 0x0648, 0x0649,
  0x064A, 0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652,
  0x0653, 0x0654, 0x0670, 0x0671, 0x06D6, 0x06D7, 0x06D8, 0x06D9, 0x06DA,
  0x06DB, 0x06DC, 0x06DE, 0x06E0, 0x06E2, 0x06E5, 0x06E6, 0x06E8, 0x06E9,
  0x06EC,
};

bool _isLetter(int c) => c >= 0x0621 && c <= 0x064A || c == 0x0671;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(QuranHarness.preload);

  test('removes exactly the five unsupported marks', () {
    for (final c in unsupportedByQuranFont) {
      final s = 'ب${String.fromCharCode(c)}ا';
      expect(quranDisplayText(s), 'با', reason: 'U+${c.toRadixString(16)}');
    }
    expect(unsupportedByQuranFont, {0x06DF, 0x06E3, 0x06EA, 0x06EB, 0x06ED});
  });

  test('text without those marks is returned untouched', () {
    const s = 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ';
    expect(identical(quranDisplayText(s), s), isTrue);
  });

  test('is idempotent', () {
    const s = 'قَيِّمًۭا لِّيُنذِرَ';
    expect(quranDisplayText(quranDisplayText(s)), quranDisplayText(s));
  });

  group('over the whole dataset', () {
    test('every code point left after adaptation is drawable by the font', () {
      final left = <int>{};
      final d = QuranHarness.data;
      for (final s in d.surahs) {
        for (final a in d.ayahsOf(s.number)) {
          left.addAll(quranDisplayText(a.text).runes);
        }
      }
      expect(left.difference(_drawableByFont), isEmpty,
          reason: 'a code point the font cannot draw (or a new one) appeared');
    });

    test('no letter is ever removed, and only the five marks are', () {
      final d = QuranHarness.data;
      var removed = 0;
      for (final s in d.surahs) {
        for (final a in d.ayahsOf(s.number)) {
          final before = a.text.runes.toList();
          final after = quranDisplayText(a.text).runes.toList();
          expect(after.where(_isLetter).toList(), before.where(_isLetter).toList(),
              reason: '${s.number}:${a.number}');
          removed += before.length - after.length;
          expect(
            before.where((c) => !after.contains(c)).every(unsupportedByQuranFont.contains),
            isTrue,
          );
        }
      }
      // ~8.8k occurrences in the full Uthmani text (BOM already stripped).
      expect(removed, inInclusiveRange(8700, 8900));
    });

    test('the stored text itself is never modified', () {
      final d = QuranHarness.data;
      var withMarks = 0;
      for (final s in d.surahs) {
        for (final a in d.ayahsOf(s.number)) {
          if (a.text.runes.any(unsupportedByQuranFont.contains)) withMarks++;
        }
      }
      expect(withMarks, greaterThan(1000));
    });
  });

  test('the adapter is on while the bundled font is incomplete', () {
    expect(SpiritualFonts.quranFontHasFullMarkSet, isFalse);
  });
}
