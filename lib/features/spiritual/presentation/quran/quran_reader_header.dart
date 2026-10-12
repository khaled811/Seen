import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/quran.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_icon_button.dart';
import 'auto_read.dart';
import 'font_size_control.dart';

/// Reader header: back, surah title with "makki · N ayahs · page P", the
/// bookmark toggle, and the font-size toolbar underneath.
class QuranReaderHeader extends StatelessWidget {
  const QuranReaderHeader({
    super.key,
    required this.surah,
    required this.page,
    required this.bookmarked,
    required this.fontSize,
    required this.canShrink,
    required this.canGrow,
    required this.onBookmark,
    required this.onSmaller,
    required this.onBigger,
    this.onShowPages,
    this.autoRunning = false,
    this.onAuto,
  });

  final Surah surah;

  /// Mushaf page of the ayah at the top of the screen.
  final int page;
  final bool bookmarked;
  final double fontSize;
  final bool canShrink;
  final bool canGrow;
  final VoidCallback onBookmark;
  final VoidCallback onSmaller;
  final VoidCallback onBigger;

  /// Switches to reading by mushaf pages (null hides the button).
  final VoidCallback? onShowPages;

  /// Hands-free reading: running state and its play/pause (null hides it).
  final bool autoRunning;
  final VoidCallback? onAuto;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final revelation = surah.revelation == Revelation.makki
        ? SpiritualStrings.makki
        : SpiritualStrings.madani;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bgReader,
        border: Border(bottom: BorderSide(color: t.readerDivider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                SpiritualIconButton(
                  icon: Icons.arrow_back,
                  semanticLabel: SpiritualStrings.back,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: SpiritualSpace.s8),
                Expanded(
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          '${SpiritualStrings.surahWord} ${surah.nameAr}',
                          textAlign: TextAlign.center,
                          style: SpiritualType.title.copyWith(
                            color: t.inkPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: SpiritualSpace.s2),
                      Text(
                        toArabicDigits(
                          '$revelation · ${surah.ayahCount} آيات · صفحة $page',
                        ),
                        textAlign: TextAlign.center,
                        style: SpiritualType.micro.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: t.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SpiritualSpace.s8),
                if (onShowPages != null) ...[
                  SpiritualIconButton(
                    icon: Icons.menu_book_outlined,
                    semanticLabel: SpiritualStrings.readerPagesView,
                    onPressed: onShowPages,
                  ),
                  const SizedBox(width: SpiritualSpace.s4),
                ],
                SpiritualIconButton(
                  icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: t.accent,
                  semanticLabel: SpiritualStrings.saveReadingPosition,
                  onPressed: onBookmark,
                ),
              ],
            ),
            const SizedBox(height: SpiritualSpace.s10),
            // Wraps onto a second line when text is scaled up.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: SpiritualSpace.s8,
              children: [
                FontSizeControl(
                  size: fontSize,
                  canShrink: canShrink,
                  canGrow: canGrow,
                  onSmaller: onSmaller,
                  onBigger: onBigger,
                ),
                if (onAuto != null)
                  AutoReadButton(running: autoRunning, onPressed: onAuto!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
