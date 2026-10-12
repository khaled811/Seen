import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/quran.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import 'quran_display_text.dart';

/// One ayah in the reader: Uthmani text with the number emblem inline, and the
/// "التفسير والترجمة" button underneath. Long-press opens the copy menu.
///
/// The text size animates (`fast`) when the user changes the font step.
class QuranAyahTile extends StatelessWidget {
  const QuranAyahTile({
    super.key,
    required this.ayah,
    required this.fontSize,
    required this.bookmarked,
    required this.openSheetAyah,
    required this.onOpenSheet,
    required this.onLongPress,
  });

  final Ayah ayah;
  final double fontSize;
  final bool bookmarked;

  /// Number of the ayah whose sheet is open (null when none); its emblem
  /// turns accent.
  final ValueListenable<int?> openSheetAyah;
  final VoidCallback onOpenSheet;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final label = '${SpiritualStrings.ayahWord} ${toArabicDigits(ayah.number)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.readerDivider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '$label: ${ayah.text}',
            onLongPress: onLongPress,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: onLongPress,
                child: SizedBox(
                  width: double.infinity,
                  child: AnimatedDefaultTextStyle(
                    duration: SpiritualMotion.of(context, SpiritualMotion.fast),
                    style: SpiritualType.quran.copyWith(
                      fontSize: fontSize,
                      height: 2.05,
                      color: t.inkPrimary,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: quranDisplayText(ayah.text)),
                          const TextSpan(text: ' '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: ValueListenableBuilder<int?>(
                              valueListenable: openSheetAyah,
                              builder: (_, open, __) => _Emblem(
                                number: ayah.number,
                                label: label,
                                active: open == ayah.number,
                                bookmarked: bookmarked,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: SpiritualSpace.s4),
          PressScale(
            onTap: onOpenSheet,
            borderRadius: BorderRadius.circular(SpiritualRadius.control),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SpiritualStrings.tafsirAndTranslation,
                      style: SpiritualType.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: t.accent,
                      ),
                    ),
                    const SizedBox(width: SpiritualSpace.s6),
                    Icon(Icons.expand_more, size: 16, color: t.accent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({
    required this.number,
    required this.label,
    required this.active,
    required this.bookmarked,
  });

  final int number;
  final String label;
  final bool active;
  final bool bookmarked;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Semantics(
      label: bookmarked ? '$label، ${SpiritualStrings.tabBookmarks}' : label,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: SpiritualMotion.of(context, SpiritualMotion.fast),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bookmarked ? t.accentTint : null,
            border: Border.all(
              color: (active || bookmarked) ? t.accent : t.octagonStroke,
              width: 1.5,
            ),
          ),
          child: Text(
            toArabicDigits(number),
            style: const TextStyle(
              fontFamily: SpiritualFonts.ui,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1,
            ).copyWith(color: t.inkBody),
          ),
        ),
      ),
    );
  }
}
