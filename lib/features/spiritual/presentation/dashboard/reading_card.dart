import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/reading_progress.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_progress_bar.dart';

/// "وِردك اليومي": today's reading goal with progress and a resume link.
class ReadingCard extends StatelessWidget {
  const ReadingCard({super.key, required this.progress, required this.onResume});

  final ReadingProgress progress;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return SpiritualCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: t.sageTint,
                  borderRadius: BorderRadius.circular(SpiritualRadius.control),
                ),
                child: Icon(Icons.menu_book_outlined, size: 24, color: t.sage),
              ),
              const SizedBox(width: SpiritualSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SpiritualStrings.dailyWird,
                      style: SpiritualType.caption.copyWith(color: t.inkMuted),
                    ),
                    const SizedBox(height: SpiritualSpace.s2),
                    Text(
                      toArabicDigits(
                        'سورة ${progress.surahName} • صفحة ${progress.page}',
                      ),
                      style: SpiritualType.bodyStrong.copyWith(
                        color: t.inkPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpiritualSpace.s8),
              Text(
                toArabicDigits('${progress.percent}٪'),
                style: SpiritualType.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: t.sage,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpiritualSpace.s14),
          SpiritualProgressBar(
            value: progress.fraction,
            fillColor: t.sage,
            semanticLabel: SpiritualStrings.readingProgress,
          ),
          const SizedBox(height: SpiritualSpace.s14),
          Row(
            children: [
              Expanded(
                child: Text(
                  toArabicDigits(
                    '${progress.pagesRead} من ${progress.pagesGoal} صفحات',
                  ),
                  style: SpiritualType.caption.copyWith(color: t.inkMuted),
                ),
              ),
              PressScale(
                onTap: onResume,
                borderRadius: BorderRadius.circular(SpiritualRadius.control),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SpiritualSpace.minTap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        SpiritualStrings.continueReading,
                        style: SpiritualType.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: t.accent,
                        ),
                      ),
                      const SizedBox(width: SpiritualSpace.s6),
                      Icon(Icons.chevron_right, size: 18, color: t.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
