// LedgerRow — one wallet ledger entry. Credit: sage arrow-in tile + green
// "+amount". Debit: slate arrow-out tile + ink "-amount". Arrows are never
// mirrored. Place rows inside a SeenListGroup with date headers.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_status.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

enum SeenLedgerType { credit, debit }

class SeenLedgerRow extends StatelessWidget {
  const SeenLedgerRow({
    super.key,
    required this.type,
    required this.title,
    required this.reference,
    required this.time,
    required this.amount,
    this.status,
    this.onTap,
  });

  final SeenLedgerType type;
  final String title;
  final String reference;
  final String time;
  final num amount;
  final SeenStatus? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    final credit = type == SeenLedgerType.credit;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: credit ? c.successBg : c.surfaceSunken,
                borderRadius: const BorderRadius.all(SeenRadius.sm),
              ),
              child: Icon(credit ? SeenIcons.credit : SeenIcons.debit, size: 18, color: credit ? c.successFg : c.slate),
            ),
            const SizedBox(width: SeenSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.bodyMedium),
                  Row(children: [
                    Flexible(
                      child: Text(reference,
                          textDirection: TextDirection.ltr,
                          overflow: TextOverflow.ellipsis,
                          style: SeenType.of(context).refMono.copyWith(fontSize: 11, color: c.inkMuted)),
                    ),
                    const SizedBox(width: SeenSpace.s2),
                    Text(time, style: text.labelSmall!.copyWith(fontFeatures: SeenFonts.tabular)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: SeenSpace.s2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(SeenFormat.signed(amount, credit: credit),
                    textDirection: TextDirection.ltr,
                    style: seenStyle(15, 22, FontWeight.w600, credit ? c.successFg : c.ink)
                        .copyWith(fontFeatures: SeenFonts.tabular)),
                if (status != null) ...[
                  const SizedBox(height: 4),
                  SeenStatusBadge(status: status!, dense: true),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
