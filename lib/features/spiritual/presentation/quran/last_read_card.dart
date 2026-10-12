import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../bloc/quran_index_state.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';

/// "آخر قراءة": the saved position with a resume button.
class LastReadCard extends StatelessWidget {
  const LastReadCard({super.key, required this.lastRead, required this.onResume});

  final LastReadSummary lastRead;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(SpiritualRadius.button + 4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: radius,
        border: Border.all(color: t.borderCard),
        boxShadow: SpiritualTokens.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.accentTint,
              borderRadius: BorderRadius.circular(SpiritualRadius.control),
            ),
            child: Icon(Icons.bookmark_border, size: 22, color: t.accent),
          ),
          const SizedBox(width: SpiritualSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SpiritualStrings.lastRead,
                  style: SpiritualType.micro.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: t.inkMuted,
                  ),
                ),
                const SizedBox(height: SpiritualSpace.s2),
                Text(
                  toArabicDigits(
                    'سورة ${lastRead.surahName} · الآية ${lastRead.ayah}',
                  ),
                  style: SpiritualType.body.copyWith(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: t.inkPrimary,
                  ),
                ),
                const SizedBox(height: SpiritualSpace.s2),
                Text(
                  toArabicDigits(
                    'صفحة ${lastRead.page} · الجزء ${lastRead.juz}',
                  ),
                  style: SpiritualType.micro.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: t.inkBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpiritualSpace.s6),
          PressScale(
            onTap: onResume,
            borderRadius: BorderRadius.circular(SpiritualRadius.control),
            child: Container(
              constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(SpiritualRadius.control),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    SpiritualStrings.resume,
                    style: SpiritualType.label.copyWith(color: Colors.white),
                  ),
                  const SizedBox(width: SpiritualSpace.s6),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
