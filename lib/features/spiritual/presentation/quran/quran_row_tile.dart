import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/quran.dart';
import '../bloc/quran_index_state.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/octagon_badge.dart';
import '../widgets/press_scale.dart';

/// One index row: octagon number, name + transliteration, meta line with the
/// Makki/Madani icon, and the start page on the trailing edge.
class QuranRowTile extends StatelessWidget {
  const QuranRowTile({super.key, required this.row, required this.onTap});

  final QuranIndexRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return PressScale(
      onTap: onTap,
      scale: 0.99,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SpiritualSpace.s10),
          child: Row(
            children: [
              OctagonBadge(number: row.number, highlighted: row.highlighted),
              const SizedBox(width: SpiritualSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: SpiritualSpace.s8,
                      children: [
                        Text(
                          row.title,
                          style: SpiritualType.bodyStrong.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: t.inkPrimary,
                          ),
                        ),
                        if (row.latin.isNotEmpty)
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              row.latin,
                              style: SpiritualType.micro.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: t.inkMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: SpiritualSpace.s4),
                    Row(
                      children: [
                        if (row.revelation != null) ...[
                          Icon(
                            row.revelation == Revelation.makki
                                ? Icons.view_in_ar_outlined
                                : Icons.mosque_outlined,
                            size: 16,
                            color: t.inkBody,
                          ),
                          const SizedBox(width: SpiritualSpace.s6),
                        ],
                        Flexible(
                          child: Text(
                            row.meta,
                            style: SpiritualType.caption.copyWith(
                              fontWeight: FontWeight.w400,
                              color: t.inkBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpiritualSpace.s8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SpiritualStrings.pageWord,
                      style: SpiritualType.micro.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: t.inkMuted,
                      ),
                    ),
                    Text(
                      toArabicDigits(row.page),
                      style: SpiritualType.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: t.inkPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
