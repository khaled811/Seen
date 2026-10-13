// LedgerRow — one wallet ledger entry (Figma 11, "Txn"). A 40 px icon tile and
// the title with a muted date line on the start side; the signed amount (green
// for money in, red for money out) with "USD" under it on the end side. The
// amount is a left-to-right run. Place rows inside a card with dividers.
import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
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
    required this.meta,
    required this.amount,
    required this.iconAsset,
    this.statusChip,
    this.onTap,
  });

  final SeenLedgerType type;
  final String title;

  /// Date and time line, e.g. "١٢ نوفمبر · 10:45".
  final String meta;

  /// Major units (dollars), always positive; [type] decides the sign.
  final num amount;

  /// A bundled SVG shown in the 40 px tile (credits sit on a green tile).
  final String iconAsset;

  /// Only for pending / rejected entries; approved is the resting state.
  final SeenStatusChip? statusChip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final credit = type == SeenLedgerType.credit;
    final signed = SeenFormat.signed(amount, credit: credit);
    final tone = credit ? SeenRequestStatus.completed.colors : SeenRequestStatus.rejected.colors;
    return Semantics(
      container: true,
      label: '$title $signed USD',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: 14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: credit ? SeenRequestStatus.completed.colors.bg : SeenBrand.violet10,
                  borderRadius: const BorderRadius.all(SeenRadius.r14),
                ),
                child: SizedBox(width: 40, height: 40, child: Center(child: SeenSvgIcon(iconAsset, size: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.ink)),
                    const SizedBox(height: 2),
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    signed,
                    textDirection: TextDirection.ltr,
                    style: t.bodyStrong.copyWith(color: tone.fg, fontFeatures: SeenFonts.tabular),
                  ),
                  Text('USD', textDirection: TextDirection.ltr, style: t.caption.copyWith(color: c.inkMuted)),
                  if (statusChip != null) ...[const SizedBox(height: 4), statusChip!],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
